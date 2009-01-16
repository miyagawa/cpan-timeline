package Social::CPAN::Web::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use LWP::UserAgent;
use JSON::XS;
use Parse::CPAN::Authors;
use WebService::Google::Contact;
use XML::Feed;
use URI;
use URI::QueryParam;

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

    $c->stash->{email_list} = $contact->get_contact;
    $c->forward('list_from_emails');
}

sub socialgraph : Path("socialgraph") {
    my($self, $c) = @_;

    my $uri = $c->req->param('uri');
    my $api = URI->new("http://socialgraph.apis.google.com/lookup");
    $api->query_form(q => $uri, fme => 1, edo => 1, sgn => 1);

    my $res = LWP::UserAgent->new->get($api);
    my $data = JSON::XS->new->decode($res->content);

    for my $value (values %{$data->{nodes}}) {
        for my $uri (keys %{$value->{nodes_referenced}}) {
            if ($uri =~ s/^sgn:/http:/) {
                my $ident = URI->new($uri)->query_param('ident') or next;
                push @{$c->stash->{account_ids}}, $ident;
            }
        }
    }

    $c->forward('list_from_ids');
}

sub list_from_emails : Private {
    my($self, $c) = @_;

    my(%by_email, %by_name);
    my $p = Parse::CPAN::Authors->new( $c->path_to("root/01mailrc.txt.gz")->stringify );
    for my $author ($p->authors) {
        $by_email{$author->email} = $author;
        $by_name{$author->name} = $author if $author->name;
    }

    my(@friend_authors, %seen);
    for my $person (@{$c->stash->{email_list}}) {
        my $author = $by_email{$person->{email}} || $by_name{$person->{name}};
        if ($author && !$seen{$author->pauseid}++) {
            if ($author->email =~ /CENSORED|\s/) {
                $author->email($person->{email});
            }
            push @friend_authors, $author;
        }
    }

    $c->stash->{friends} = \@friend_authors;
    $c->stash->{parser}  = $p;
    $c->forward('render_timeline');
}

sub list_from_ids : Private {
    my($self, $c) = @_;

    my $p = Parse::CPAN::Authors->new( $c->path_to("root/01mailrc.txt.gz")->stringify );
    my @friend_authors;
    for my $id (@{$c->stash->{account_ids}}) {
        my $author = $p->author(uc $id) or next;
        push @friend_authors, $author;
    }

    $c->stash->{friends} = \@friend_authors;
    $c->stash->{parser}  = $p;
    $c->forward('render_timeline');
}

sub render_timeline : Private {
    my($self, $c) = @_;

    my %seen;
    $c->stash->{friends} = [ grep !$seen{$_->pauseid}++, @{$c->stash->{friends}} ];

    my $uri = "http://unknownplace.org/cpanrecent/rss/author/" . join("+", map lc $_->pauseid, @{$c->stash->{friends}});
    my $feed = XML::Feed->parse(URI->new($uri));

    $c->stash->{feed} = $feed;
    $c->view('TD')->template('timeline');
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
