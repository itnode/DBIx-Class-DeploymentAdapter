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

        $self->dh_store( DBIx::Class::DeploymentHandler->new( $args ) );

    }

    return $self->dh_store;
}

1;
