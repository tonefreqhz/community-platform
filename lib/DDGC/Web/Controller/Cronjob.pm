package DDGC::Web::Controller::Cronjob;
# ABSTRACT: Trick controller todo cronjobs through web framework

use Moose;
use namespace::autoclean;

use DDGC::Config;
use DDGC::Util::DateTime;

BEGIN {extends 'Catalyst::Controller'; }

sub base :Chained('/base') :PathPart('cronjob') :CaptureArgs(0) {
	my ( $self, $c ) = @_;
	if (defined $ENV{DDGC_EXECUTE_CRONJOBS}
			&& $ENV{DDGC_EXECUTE_CRONJOBS} eq 'YES'
			&& $c->req->address eq '127.0.0.1') {
		return;
	}
	$c->response->status(403);
	$c->response->body('Not allowed');
	return $c->detach;
}

sub index :Chained('base') :PathPart('') :Args {
	my ( $self, $c, @args ) = @_;
	if ($args[0] eq 'notify_cycle') {
		$self->notify_cycle($c,$args[1]);
	}
	$c->response->body('OK');
}

sub notify_cycle {
	my ( $self, $c, $cycle ) = @_;
	$c->stash->{c} = $c;
	$c->stash->{u} = sub {
		my @args;
		for (@_) {
			if (ref $_ eq 'ARRAY') {
				push @args, @{$_};
			} else {
				push @args, $_;
			}
		}
		return $c->chained_uri(@args);
	};
	$c->stash->{dur} = sub { DDGC::Util::DateTime::dur($_[0]) };
	$c->stash->{dur_precise} = sub { DDGC::Util::DateTime::dur_precise($_[0]) };

	my $users_ids_rs = $c->d->envoy->unsent_notifications_cycle_users($cycle);

	my @results = $users_ids_rs->all;

	for (@results) {
		my $users_id = $_->get_column('users_id');
		my $user = $c->d->rs('User')->find($users_id);
		if ($user->data && $user->data->{email}) {
			$c->stash->{current_user} = $user;
			$c->stash->{unsent_notifications_results} = [$user->unsent_notifications_cycle($cycle)->all];
			eval {
				$c->d->postman->template_mail(
					$user->data->{email},
					'"DuckDuckGo Community Envoy" <envoy@dukgo.com>',
					'[DuckDuckGo Community] New notifications for you',
					'notifications',
					$c->stash,
				);
			};
			unless ($@) {
				my @ids;
				for (@{$c->stash->{unsent_notifications_results}}) {
					for ($_->event_notifications) {
						push @ids, $_->id;
					}
				}
				$c->d->rs('Event::Notification')->search({
					id => { -in => \@ids },
				})->update({ sent => 1 });
			}
		}
	}

}

__PACKAGE__->meta->make_immutable;

1;
