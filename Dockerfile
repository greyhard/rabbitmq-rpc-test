FROM debian:jessie-slim

RUN apt-get update && apt-get install -y \
    make \
    cmake \
    curl libnet-ssleay-perl

RUN apt-get install -y \
    gcc libanyevent-rabbitmq-perl

RUN curl -L http://cpanmin.us | perl - App::cpanminus

RUN cpanm LWP::Protocol::https Modern::Perl \
    JSON::XS IO::Socket::SSL Mojolicious YAML::XS \
    Mojolicious::Plugin::MailException \
    Modern::Perl \
    IO::Socket::Socks Net::DNS::Native LWP::Protocol::socks

RUN cpanm --force Net::RabbitMQ
RUN echo '1'

COPY ./searchd_sync.pl /searchd_sync.pl

CMD ["perl","/searchd_sync.pl"]