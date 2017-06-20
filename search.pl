#!/usr/bin/perl

use strict;
use warnings;
use Modern::Perl;
$|++;

use Net::RabbitMQ;
use UUID::Tiny;
use YAML::XS;

sub fibonacci_rpc($) {
    my $n = shift;

    my $corr_id = UUID::Tiny::create_UUID_as_string(UUID::Tiny::UUID_V4);

    my $mq = Net::RabbitMQ->new();

    $mq->connect("localhost", {
            host => 'localhost',
            port => 5672,
            user => 'guest',
            pass => 'guest',
            vhost => '/',
        });

    $mq->channel_open(1);


    $mq->queue_declare(1,$corr_id,{auto_delete => 1,exclusive => 1});

    $mq->publish(1,'rpc_queue',$n,{},{correlation_id => $corr_id});

    while(1){
        if (my $var = $mq->get(1, $corr_id)) {
            if($corr_id eq $var->{routing_key}){
                return $var->{body};
            }else{
                return undef;
            }
        }
        say "wait RPC";
        sleep 1;
    }
}

my @arr = (
    '419602##DORMAN',
    'P856##CARLSON',
    '799706'
);

while ( my $part = shift @arr) {

    my $try = 5;
    my $response;

    for(my $i = 0;$i < $try;$i++){
        print " [$i][$part] Sent\n";
        $response = fibonacci_rpc($part);
        if($response && $response ne "timeout"){
            last;
        }
    }
    
    print " [.] Got $response\n";

}
