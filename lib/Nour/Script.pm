# vim:ts=4 sw=4 expandtab smarttab smartindent autoindent cindent
package Nour::Script; use strict; use warnings;
# ABSTRACT: script bootstrap

use Moose::Role; with 'Nour::Base';
use namespace::autoclean;
use String::CamelCase qw/decamelize/;
use Getopt::Long qw/:config pass_through/;


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
        my $self = shift;
        return new Nour::Config ( -base => $self->_config_path );
    }
);
sub _config_path_auto {
    my $self = shift;
    return $self->path( qw/config/, map { decamelize $_ } split /::/, ref $self );
}
has _config_path => (
    is => 'rw'
    , isa => 'Str'
    , lazy => 1
    , required => 1
    , default => sub {
        my $self = shift;
        my $path =  $self->_config_path_auto;
        my $base = -d $path ? $path : $self->path( 'config' );
        return $base;
    }
);
has option => (
    is => 'rw'
    , isa => 'HashRef'
    , required => 1
    , lazy => 1
    , default => sub {
        my ( $self, %opts ) = @_;

        $self->merge_hash( \%opts, $self->config->{option}{default} ) if $self->config->{option}{default};

        GetOptions( \%opts
            , qw/
                mode=s
                verbose+
            /
            , silent => sub {
                $opts{verbose} = 0;
                $opts{silent}  = 1;
            }
            , $self->config->{option}{getopts} ? @{ $self->config->{option}{getopts} } : ()
        );

        return \%opts;
    }
);

do {
    my $method = $_;
    around $method => sub {
        my ( $next, $self, @args ) = @_;
        return $self->$next( @args ) unless $self->option->{silent};
        return $self->$next( @args ) if $method eq 'log' and not @args;
        return;
    };
} for qw/debug info log/;


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
        $conf{ '-opts' }{database} = $self->option->{mode} if $self->option->{mode} and not grep {
            $_ eq '--database' # --database will get processed by nour::database
        } @ARGV;
        $conf{ '-opts' }{log} = $self->log->mojo unless $self->option->{silent}; #_logger->_logger;
        return new Nour::Database ( %conf );
    }
);

before run => sub {
    my $self = shift;
    $self->info( ref $self );
    $self->debug( 'using configuration from', $self->_config_path, $self->config ) if -d $self->_config_path and $self->_config_path eq $self->_config_path_auto;
    $self->debug( 'configuration file not found, place your config in', $self->_config_path_auto ) unless $self->_config_path eq $self->_config_path_auto;
    $self->debug( 'using options', $self->option );
};

after run => sub {
    my $self = shift;
    $self->info( ref( $self ) .' finished' );
};


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Nour::Script - script bootstrap

=head1 VERSION

version 0.04

=head1 NAME

Nour::Script

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
