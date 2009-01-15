package Social::CPAN::Web::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use Parse::CPAN::Authors;
use WebService::Google::Contact;
use XML::Feed;
use URI;

__PACKAGE__->config->{namespace} = '';

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->view('TD')->template('index');
}

sub gmail :Local {
    my($self, $c) = @_;

    my $contact = WebService::Google::Contact->new;
    my $next_uri = $contact->uri_to_login( $c->uri_for("/gmail/authenticate") );

    $c->res->redirect( $next_uri );
}

sub gmail_authenticate :Path("gmail/authenticate") {
    my($self, $c) = @_;

    my $token = $c->request->param('token');
    my $contact = WebService::Google::Contact->new;

    eval { $contact->verify($token) or die "Auth failed" };
    if ($@) {
        $c->stash->{expired} = 1;
        $c->detach("index");
    }

    my(%by_email, %by_name);
    my $p = Parse::CPAN::Authors->new( $c->path_to("root/01mailrc.txt.gz")->stringify );
    for my $author ($p->authors) {
        $by_email{$author->email} = $author;
        $by_name{$author->name} = $author if $author->name;
    }

    my(@friend_authors, %seen);
    for my $person (@{$contact->get_contact}) {
        my $author = $by_email{$person->{email}} || $by_name{$person->{name}};
        if ($author && !$seen{$author->pauseid}++) {
            if ($author->email =~ /CENSORED|cpan.org|\s/) {
                $author->email($person->{email});
            }
            push @friend_authors, $author;
        }
    }

    my $uri = "http://unknownplace.org/cpanrecent/rss/author/" . join("+", map lc $_->pauseid, @friend_authors);
    my $feed = XML::Feed->parse(URI->new($uri));

    $c->stash->{contact} = $contact;
    $c->stash->{parser}  = $p;
    $c->stash->{friends} = \@friend_authors;
    $c->stash->{feed}    = $feed;
}

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub end : Private {
    my($self, $c) = @_;

    return 1 if $c->req->method eq 'HEAD';
    return 1 if $c->response->body && length( $c->response->body );
    return 1 if $c->response->status =~ /^(?:204|3\d\d)$/;

    if ($c->view->isa('Template::Declare')) {
        $c->detach('View::TD');
    } else {
        $c->forward($c->view);
    }
}

1;
