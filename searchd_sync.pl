#!/usr/bin/perl
use Mojo::UserAgent;
use Modern::Perl;
use Net::RabbitMQ;
use YAML::XS;

my $ua;
my $connected;
my $reconnect = 60;

use Net::RabbitMQ;
my $mq = Net::RabbitMQ->new();

$mq->connect("rabbitmq", {
        host => 'rabbitmq',
        port => 5672,
        user => 'guest',
        pass => 'guest',
        vhost => '/',
    });


$mq->channel_open(1);
$mq->queue_declare(1,'rpc_queue',{auto_delete => 0}); 

reconnect();

sub reconnect {
    while(!$connected){
        warn "Connect";
        $ua = undef;
        $ua = Mojo::UserAgent->new;
        $ua->cookie_jar(Mojo::UserAgent::CookieJar->new);
        $ua->max_redirects(5)->connect_timeout(30)->request_timeout(30);
        $ua->transactor->name('Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)');
        $ua->proxy->http('socks://torpool:5566')->https('socks://torpool:5566');
        warn $ua->get('https://api.ipify.org?format=json')
                ->result->json('/ip');

        my $tx = $ua->get('https://www.partswebsite.com/');
        if (my $res = $tx->success) {
            unless ($res->body =~ /ADDCARERROROCCURRED/) {
                warn "No partswebsite!!";
                next;
            }
            warn "Connected partswebsite!!";
            $connected = 1;
            $reconnect = 60;
        } else {
            my $err = $tx->error;
            warn "$err->{code} response: $err->{message}" if $err->{code};
            warn "Connection error: $err->{message}";
            $connected = 0;
        }
    }
}

sub search {
    my $var = shift;
    my $body = $var->{body};
    my $props = $var->{props};
    warn " [x] Search $body";

    $ua->max_redirects(1)->connect_timeout(5)->request_timeout(5);
    my ($part,$make) = split(/##/,$body);
    chomp $part;
    chomp $make if $make;

    my $source = "https://www.partswebsite.com/catalog/catalogxml.php";
    my $tx;

    if($make){
        warn "With Make";
        $tx = $ua->post($source => form => {func => 'partsearch', searchtext => $part, make => $make});
    }else{
        $tx = $ua->post($source => form => {func => 'partsearch', searchtext => $part});
    }

    if (my $res = $tx->success) {
        $mq->publish(1,$props->{correlation_id},$res->body,{},{correlation_id => $props->{correlation_id}});
    }else {
        my $err = $tx->error;
        warn "$err->{code} response: $err->{message}" if $err->{code};
        warn "Connection error: $err->{message}";
        $connected = 0;
        $mq->publish(1,$props->{correlation_id},'timeout',{},{correlation_id => $props->{correlation_id}});
        reconnect();
    }
}

while(1){
    if($connected) {
        if (my $data = $mq->get(1, 'rpc_queue')) {
            search($data);
        }
    }
    unless($reconnect--){
        warn "Reconnect";
        $connected = 0;
        reconnect();
    }
    sleep 1;
}
