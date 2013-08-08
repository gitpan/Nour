# vim:ts=4 sw=4 expandtab smarttab smartindent autoindent cindent
package Nour::Script;
# ABSTRACT: script bootstrap

use Moose::Role;
use namespace::autoclean;
use strict; use warnings;

with 'Nour::Base';

use Nour::Logger;
use Nour::Config;
use Nour::Database;
use String::CamelCase qw/camelize decamelize/;

has _logger => (
    is => 'rw'
    , isa => 'Nour::Logger'
    , handles => [ qw/debug error fatal info log warn/ ]
    , required => 1
    , lazy => 1
    , default => sub {
        return new Nour::Logger;
    }
);

has _config => (
    is => 'rw'
    , isa => 'Nour::Config'
    , handles => [ qw/config/ ]
    , required => 1
    , lazy => 1
    , default => sub {
        return new Nour::Config ( -base => 'config' );
    }
);

has _database => (
    is => 'rw'
    , isa => 'Nour::Database'
    , handles => [ qw/db/ ]
    , lazy => 1
    , required => 1
    , default => sub {
        my $self = shift;
        my %conf = $self->config->{database} ? %{ $self->config->{database} } : (
            # default options here
        );
        %conf = ();
        return new Nour::Database ( %conf );
    }
);

before run => sub {
    my $self = shift;
    $self->info( 'running '. ref $self );
};

after run => sub {
    my $self = shift;
    $self->info( 'successfully ran '. ref $self );
};

sub run {
    my ( $self ) = @_;
    $self->fatal( ref( $self ) .' must define a "run" method' );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Nour::Script - script bootstrap

=head1 VERSION

version 0.02

=head1 DESCRIPTION

Script bootstrap.

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
