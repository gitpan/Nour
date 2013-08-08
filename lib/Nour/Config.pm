# vim: ts=4 sw=4 expandtab smarttab smartindent autoindent cindent
package Nour::Config;
# ABSTRACT: useful yaml config

use Moose;
use namespace::autoclean;
use YAML qw/LoadFile DumpFile/;
use File::Find;

with 'Nour::Base';

has _config => (
    is => 'rw'
    , isa => 'HashRef'
    , required => 1
    , lazy => 1
    , default => sub { {} }
);

has _path => (
    is => 'rw'
    , isa => 'HashRef'
);


around BUILDARGS => sub {
    my ( $next, $self, @args, $args ) = @_;

    $args = $self->$next( @args );
    $args->{_config} = delete $args->{ '-conf' } if defined $args->{ '-conf' };
    $args->{_path}{ $_ } = delete $args->{ $_ } for grep { $_ ne '_config' } keys %{ $args };
    $args->{_path} ||= {};

    return $args;
};

around BUILD => sub {
    my ( $next, $self, @args ) = @_;

    # Get config directory.
    my %path;
    if ( keys %{ $self->_path } ) {
        for my $name ( keys %{ $self->_path } ) {
            my $path = $self->_path->{ $name };

            if ( $path =~ /^\// and -d $path ) {
                $path{ $name } = $path;
            }
            elsif ( -d $self->path( $path ) ) {
                $path{ $name } = $self->path( $path );
            }
            else {
                for my $sub ( qw/config conf cfg/ ) {
                    if ( -d $self->path( $sub, $path ) ) {
                        $path{ $name } = $self->path( $sub, $path );
                        last;
                    }
                }
            }
        };
    }
    else {
        check: for my $sub ( qw/config conf cfg/ ) {
            my $path = $self->path( $sub );
            if ( -d $path ) {
                $path{ '-base' } = $path;
                last check;
            }
        }
    }
    return $self->$next( @args ) unless %path;

    my $conf = {};
    if ( my $path = $path{ '-base' } ) {
        finddepth( sub {
            my $name = $File::Find::name;
            if ( $name =~ qr/\w+\.yml$/ ) {
                my ( $key, $val );
                $val = $name;
                $val =~ s/\/\w+\.yml$//;
                $key = $val;
                $key =~ s/^\Q$path\E\/?//;
                my @key = split /\//, $key;
                $path{ $key } = $val if $key and not $path{ $key } and $key[ -1 ] ne 'private';
            }
        }, $path );
    }

    # Get config files and embedded configuration.
    for my $name ( keys %path ) {
        my @name = split /\//, $name;
        my $path = $path{ $name };
        my $conf = $conf;
        for my $name ( @name ) {
            next if $name eq '-base';
            $conf = $conf->{ $name } ||= {};
        }

        $self->build( conf => $conf, path => $path, name => $name );
    }

    $self->config( $conf );

    return $self->$next( @args );
};


sub config {
    my $self = shift;
    my @args = @_;

    if ( @args and defined $args[0] ) {
        return $self->_config->{ $args[0] } if scalar @args eq 1 and not ref $args[0];

        my %config = ref $args[0] eq 'HASH' ? %{ $args[0] } : @args;

        for my $key ( keys %config ) {
            $self->_config->{ $key } = $config{ $key };
        }
    }

    return $self->_config;
}


sub build {
    my ( $self, %args ) = @_;
    my ( %file, %conf );

    opendir my $dh, $args{path} or die "Couldn't open directory '$args{path}': $!";
    push @{ $file{public} }, map { "$args{path}/$_" } grep {
        -e "$args{path}/$_" and $_ !~ /^\./ and $_ =~ /\.yml$/
    } readdir $dh;
    closedir $dh;

    # Private sub-dir i.e. "./config/private" for sensitive i.e. .gitignore'd config.
    if ( -d "$args{path}/private" ) {
        my $path = "$args{path}/private";
        opendir my $dh, $path or die "Couldn't open directory '$path': $!";
        push @{ $file{private} }, map { "$path/$_" } grep {
            -e "$path/$_" and $_ !~ /^\./ and $_ =~ /\.yml$/
        } readdir $dh;
        closedir $dh;
    }

    for my $file ( @{ $file{public} } ) {
        my ( $name ) = ( split /\//, $file )[ -1 ] =~ /^(.*)\.yml$/;
        my $conf = LoadFile $file;

        if ( $name eq 'config' or $name eq 'base' ) {
            $conf{public}{ $_ } = $conf->{ $_ } for keys %{ $conf };
        }
        else {
            if ( exists $conf->{ $name } and scalar keys %{ $conf } == 1 ) {
                $conf{public}{ $name } = $conf->{ $name };
            }
            else {
                $conf{public}{ $name }->{ $_ } = $conf->{ $_ } for keys %{ $conf };
            }
        }
    }

    for my $file ( @{ $file{private} } ) {
        my ( $name ) = ( split /\//, $file )[ -1 ] =~ /^(.*)\.yml$/;
        my $conf = LoadFile $file;

        if ( $name eq 'config' or $name eq 'base' ) {
            $conf{private}{ $_ } = $conf->{ $_ } for keys %{ $conf };
        }
        else {
            if ( exists $conf->{ $name } and scalar keys %{ $conf } == 1 ) {
                $conf{private}{ $name } = $conf->{ $name };
            }
            else {
                $conf{private}{ $name }->{ $_ } = $conf->{ $_ } for keys %{ $conf };
            }
        }
    }

    # "Private" config overrides "public."
    $conf{merged} = {};

    $self->merge_hash( $conf{merged}, $conf{public} )  if exists $conf{public};
    $self->merge_hash( $conf{merged}, $conf{private} ) if exists $conf{private};

    $self->merge_hash( $args{conf}, $conf{merged} );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Nour::Config - useful yaml config

=head1 VERSION

version 0.02

=head1 DESCRIPTION

Very useful YAML configuration handler.

=head1 METHODS

=head2 config

Does stuff.

=head2 build

Does other stuff.

=head2 OPTIONS

Stuff stuff.

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
