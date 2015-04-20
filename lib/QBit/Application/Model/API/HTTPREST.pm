package Exception::API::HTTPREST;
use base qw(Exception::API);

sub new {
    my ($class, $response) = @_;

    my $self;
    if (ref($response) eq 'HTTP::Response') {
        $self = $class->SUPER::new($response->status_line);
        $self->{response} = $response;
    } else {
        $self = $class->SUPER::new($response);
    }

    return $self;
}

package QBit::Application::Model::API::HTTPREST;

use qbit;

use base qw(QBit::Application::Model::API);

use LWP::UserAgent;

sub init {
    my ($self) = @_;

    $self->SUPER::init();

    $self->{'__LWP__'} = LWP::UserAgent->new(timeout => $self->get_option('timeout', 300));
}

sub request {
    my ($self, $request) = @_;
    my ($retries, $content, $response) = (0);

    while (($retries < $self->get_option('attempts', 3)) && !defined($content)) {
        sleep($self->get_option('delay', 1)) if $retries++;
        $response = $self->{'__LWP__'}->request($request);

        if ($response->is_success()) {
            $content = $response->decoded_content();
            last;
        }
        if ($response->code == 408 && !$self->get_option('timeout_retry')) {
            last;
        }
    }

    $self->log(
        {
            request  => $response->request->as_string,
            url      => $response->request->uri->as_string,
            status   => $response->code,
            response => $response->headers->as_string,
            (defined($content) ? (content => $content) : (error => $response->status_line)),
        }
    ) if $self->can('log');

    throw Exception::API::HTTPREST $response unless defined($content);
    return $content;
}

TRUE;
