package Social::CPAN::Web::View::TD::Root;
use strict;
use warnings;
use Template::Declare::Tags;

BEGIN {
create_wrapper wrap => sub {
    my($code, $c, $stash) = @_;

    html {
        head {
            title { "CPAN Timeline" };
            link {
                attr {
                    rel => 'stylesheet',
                    href => '/static/css/screen.css',
                    type => 'text/css',
                    media => 'screen,projection',
                };
            };
            outs_raw '<!--[if IE]><link rel="stylesheet" href="/static/css/ie.css" type="text/css" media="screen, projection"><![endif]-->';
            link {
                attr {
                    rel => 'stylesheet',
                    href => '/static/css/site.css',
                    type => 'text/css',
                };
            };
        };
        body {
            div { attr { class => "container" };
                  h1 { class is "title"; a { href is $c->uri_for("/"); "CPAN Timeline" } };
                  $code->($c, $stash);
                  footer();
              };
        };
    };
};
}

sub footer {
    div {
        my @stuff = (
            [ 'Perl', "http://perl.org/" ],
            [ 'Catalyst', 'http://dev.catalyst.perl.org/' ],
            [ "search.cpan.org", "http://search.cpan.org/" ],
            [ "Parse::CPAN::Authors", "http://search.cpan.org/~lbrocard/Parse-CPAN-Authors/" ],
            [ "Google Contacts Data API", "http://code.google.com/apis/contacts/" ],
            [ "Google Social Graph API", "http://code.google.com/apis/socialgraph/" ],
            [ "CPAN Recent Changes", "http://unknownplace.org/cpanrecent/" ],
            [ "Gravatar", "http://www.gravatar.com/" ],
        );
        id is "footer";
        outs "Built by Tatsuhiko Miyagawa using the following stuff.";
        ul {
            class is "inline";
            my $i = 0;
            for my $stuff (@stuff) {
                li {
                    class is "first" if $i++ == 0;
                    a { target is "_blank"; href is $stuff->[1]; $stuff->[0] };
                };
            }
        }
    };
}

sub forkme {
    a { href is "http://github.com/miyagawa/cpan-timeline";
        img {
            style is "position:absolute; top:0; right:0; border:0";
            src is "http://s3.amazonaws.com/github/ribbons/forkme_right_red_aa0000.png";
            alt is "Fork me on GitHub";
        } };
}

sub dumper {
    my @args = @_;
    local $Data::Dumper::Indent = 1;
    textarea { class is "text-dump";
               style is "width:600px;height:400px";
               outs Data::Dumper::Dumper(@args) };
}

template '/index' => sub {
    my($self, $c, $stash) = @_;

    wrap {
        h2 { "Find what your friends are hacking on." };
        if ($stash->{expired}) {
            h4 { class is "error"; "Google Authe token expired. Try again." };
        }
        form {
            attr { action => $c->uri_for("/gmail"), method => 'post' };
            input { attr { type => "submit", value => " Sign in via Gmail " } };
        };

        form {
            attr { class is "spacy"; action => $c->uri_for('/socialgraph'), method => 'get' };
            label { attr { for => 'uri' }; "URL:" };
            input { attr { type => 'text', size => 24, name => 'uri' } };
            span { class is "gray"; " (e.g. twitter.com/miyagawa)" };
        };

        div {
            class is "spacy";
            h4 { class is "how"; "How does this work?" };
            div { "This gets your contacts using Google Contacts API (Gmail and Google Talk) or Social Graph API, searches PAUSE accounts matching with their email or name (in Social Graph search we assume their account ID matches with PAUSE one, which should not be always true), and displays the recent activities by them." };
        };

        forkme();
    } $c, $stash;
};

template '/timeline' => sub {
    my($self, $c, $stash) = @_;

    wrap {
        div {
            class is "result";
            h3 { "You have " . scalar @{$stash->{friends}} . " friends on CPAN." };
            if ($c->request->param('token')) {
                h4 { class is "warning"; "Don't share this URL. It is not bookmarkable (yet)." };
            }
        };

        div {
            id is "recent-uploads";
            if ($stash->{feed}) {
                for my $entry ($stash->{feed}->entries) {
                    my $pauseid = ($entry->link =~ /\~(\w+)/)[0] or next;
                    my $author = $stash->{parser}->author(uc $pauseid) or next;
                    div {
                        class is "activity";
                        link_with_face($author, 24);
                        a { href is "http://search.cpan.org/~$pauseid/"; $entry->author };
                        outs " uploaded ";
                        a { href is $entry->link; $entry->title };
                        outs " on " . $entry->issued;
                    };
                }
            } else {
                div {
                    class is "error";
                    "Parsing CPAN Recent feed failed.";
                };
            }
        };

        div {
            id is "friend-list";

            for my $author (@{$stash->{friends}}) {
                div {
                    class is 'author-face';
                    link_with_face($author, 32);
                };
            }
        };
    } $c, $stash;
};

sub link_with_face {
    my $author = shift;
    my $size  = shift || 32;
    a {
        href is "http://search.cpan.org/~" . lc $author->pauseid . "/";
        img {
            class is "avatar-image";
            src is gravatar_url($author, $size);
            title is $author->name;
            width is $size; height is $size;
        };
    };
}

sub gravatar_url {
    my($author, $size) = @_;
    my $hash = md5_hex($author->email);

    my $default  = "http://st.pimg.net/tucs/img/who.jpg";
    my $fallback = $author->email !~ /cpan\.org/
        ? _gravatar( $author->email, $size, $default ) : $default;

    return _gravatar( lc($author->pauseid) . '@cpan.org', $size, $fallback);
}

sub _gravatar {
    my($email, $size, $default) = @_;

    use Digest::MD5 qw(md5_hex);
    use URI;
    my $uri = URI->new("http://www.gravatar.com/avatar.php");
    $uri->query_form( gravatar_id => md5_hex($email), rating => 'G', size => $size, default => $default );
    return $uri;
}



1;
