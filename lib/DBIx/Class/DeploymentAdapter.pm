package DBIx::Class::DeploymentAdapter;
use 5.008001;
use strict;
use warnings;

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

sub install {

    my ( $self ) = @_;

    return unless $self->dh;

    $self->dh->install;
}

sub prepare {

    my ($self) = @_;

    return unless $self->dh;

    my $start_version  = $self->dh->database_version;
    my $target_version = $self->dh->schema->schema_version;

    $dh->prepare_install;

    $dh->prepare_upgrade(
        {
            from_version => $start_version,
            to_version   => $target_version,
        }
    );

    $dh->prepare_downgrade(
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

    my ( $self ) = @_;

    return unless $self->dh;

    my $start_version  = $self->dh->database_version;
    my $target_version = $self->dh->schema->schema_version;

    my $start_version  = $self->dh->database_version + 1;
    my $target_version = $schema->schema_version;

    for my $version ( $start_version .. $target_version ) {

        if( $options->{to_version} && $version >= $options->{to_version} ) {
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
