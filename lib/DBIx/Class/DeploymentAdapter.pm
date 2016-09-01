package DBIx::Class::DeploymentAdapter;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.03";

use DBIx::Class::DeploymentHandler;

use Moose;

has dh_store => (
    is  => "rw",
    isa => "Maybe[Object]"
);

sub dh {

    my ( $self, $args ) = @_;

    if ( !$self->dh_store ) {

        return unless $args && $args->{schema};

        $args->{script_directory}    ||= "./share/migrations";
        $args->{databases}           ||= ["MySQL"];
        $args->{sql_translator_args} ||= { mysql_enable_utf8 => 1 };

        $self->dh_store( DBIx::Class::DeploymentHandler->new($args) );

    }

    return $self->dh_store;
}

around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;

    if( @_ == 1 && ref $_[0] eq "HASH" ) {

        $class->dh($_[0]);
    }

    return $class->$orig(@_);
};

sub install {

    my ( $self ) = @_;

    return unless $self->dh;

    $self->dh->install;
}

sub backup {

    my ( $self, $dbname ) = @_;

    return unless $self->dh;

    $self->dh->version_storage_is_installed
      || die "No Database to populate!";

    my $version = $self->dh->database_version;

    my $response = qx~mysqldump $dbname | gzip /tmp/$dbname.sql.gz~;

    die "Backup: $response" if $response;
}

sub prepare {

    my ($self) = @_;

    return unless $self->dh;

    my $start_version  = $self->dh->database_version;
    my $target_version = $self->dh->schema->schema_version;

    $self->dh->prepare_install;

    $self->dh->prepare_upgrade(
        {
            from_version => $start_version,
            to_version   => $target_version,
        }
    );

    $self->dh->prepare_downgrade(
        {
            from_version => $target_version,
            to_version   => $start_version,
        }
    );
}

sub status {

    my ( $self ) = @_;

    return unless $self->dh;

    my $deployed_version = $self->dh->database_version;
    my $schema_version   = $self->dh->schema->schema_version;

    return sprintf( "Schema is %s\nDeployed database is %s\n", $schema_version, $deployed_version );

}

sub upgrade_incremental {

    my ( $self, $to_version ) = @_;

    return unless $self->dh;

    my $start_version  = $self->dh->database_version;
    my $target_version = $self->dh->schema->schema_version;

    my $start_version  = $self->dh->database_version + 1;
    my $target_version = $self->dh->schema->schema_version;

    for my $version ( $start_version .. $target_version ) {

        if( $to_version && $version >= $to_version ) {
            next;
        }

        warn "upgrading to version $version\n";

        eval {
            my ( $ddl, $sql ) = @{ $self->dh->upgrade_single_step( { version_set => [ $version - 1, $version ] } ) || [] };    # from last version to desired version
            $self->dh->add_database_version(
                {
                    version     => $version,
                    ddl         => $ddl,
                    upgrade_sql => $sql,
                }
            );
        };

        if ($@) {
            my $error_version = $self->dh->database_version;
            warn "Database remains on version $error_version";
            die "UPGRADE ERROR - Version $error_version upgrading to $version: " . $@;
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

DBIx::Class::DeploymentAdapter - Deployment handler adapter to your DBIC app, which offers some candy

=head1 SYNOPSIS

    use DBIx::Class::DeploymentAdapter;

=head1 DESCRIPTION

Deployment handler adapter to your DBIC app, which offers some candy

=head1 LICENSE

Copyright (C) Patrick Kilter.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Patrick Kilter E<lt>pk@gassmann.itE<gt>

=cut
