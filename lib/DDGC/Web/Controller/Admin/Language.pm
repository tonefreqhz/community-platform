package DDGC::Web::Controller::Admin::Language;
# ABSTRACT: Language administration web controller class

use Moose;
BEGIN { extends 'Catalyst::Controller'; }

use namespace::autoclean;

sub base :Chained('/admin/base') :PathPart('language') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	$c->add_bc('Language editor', $c->chained_uri('Admin::Language','index'));
}

sub index :Chained('base') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;
	$c->bc_index;

	if ($c->req->param('save_language')) {
		my %data;
		for (keys %{$c->req->params}) {
			if ($_ =~ m/^language_(\d+)_(.+)$/) {
				my $id = $1;
				my $key = $2;
				$data{$id} = {} unless defined $data{$id};
				$data{$id}->{$key} = $c->req->param($_);
			}
		}
		for my $id (keys %data) {
			my $values = $data{$id};
			if ($id > 0) {
				my $language = $c->d->rs('Language')->find($id);
				die "language id ".$_." not found" unless $language;
				for (keys %{$values}) {
					$language->$_($values->{$_});
				}
				$language->update;
				$c->stash->{changed_language_id} = $id;
			} else {
				my $new_language = $c->d->rs('Language')->create($values);
				$c->stash->{changed_language_id} = $new_language->id;
			}
		}
	}

	$c->stash->{languages} = $c->d->rs('Language')->search({},{
		order_by => { -desc => 'me.updated' },
	});

}

no Moose;
__PACKAGE__->meta->make_immutable;
