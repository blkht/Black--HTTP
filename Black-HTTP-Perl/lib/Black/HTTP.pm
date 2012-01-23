package Black::HTTP;

use 5.010001;
use strict;
use warnings;
use MD5;
use MIME::Base64;
use Exporter;

# just for debbugging
use Data::Dump qw-dump-;

use constant 'DEBUG' => 0;
use constant 'ERRORS' => 0;

no strict 'refs';
no strict 'subs';

our (@ISA, $VERSION);

@ISA = qw/Exporter/;

our %EXPORT_TAGS = (
    'all' => [ qw( ) ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
#our @EXPORT_OK = ( );
our @EXPORT = qw/
    new get set
/;

$VERSION = '0.01';

# Na az van hogy osszemasoltam a ket modult, ugyhogy omlesztve vannak itt a szarok.
# ebbol kene egy tiszta verziot osszehozni



# TODO:
# - gzip
# - keep alive

	#
	# DEBUGGING AND ETC
	#
#	'debug' =>		[0,	'turn on debug'],
	#
	# REQUEST LINE
	#
#	'url' =>		[1,	'set url'],
#	'method' =>		[1,	'set request[ed] method'],
#	'uri' =>		[1,	'set arbitary request URI'],
#	'protocol' =>		[1,	'set request protocol'],
	#
	# HEADERS
	#
#	'vhost' =>		[1,	'vhost, set Host header'],
#	'headers' =>		[1,	'set Header'],
#	'no-default-headers' =>	[0,	'dont set default Headers'],
#	'strict-headers' =>	[1,	'set Strict Header'],
#	'crlf' =>		[1,	'sortores. defaults to \r\n'],
#	'hfs' =>		[1,	'header field separator. defaults to ": "'],
#	'http-auth' =>		[1,	'basic http auth'],
#	'help' =>		[0,	'dump help'],
#	'postdata' =>		[1,	'post data'],
#	'rawpostdata' =>	[1,	'raw post data'],


sub new
{
    my $type = shift;
    my $this = {};
    $this->{'options'} = {};	# parameters given by the user
    $this->{'build'} = {};
    $this->{'request'} = {};	# request object
    $this->{'response'} = {};	# tha http request
    my %options = @_;
    while (my ($k, $v) = each %options)
    {
	$this->{'options'}{$k} = $v;
    }
    bless $this, $type;
    $this->_prepare();
    $this->_build();
    return $this;
}



sub _prepare
{
    my $this = shift;
    
    my $opt = \%{$this->{options}};
    my $req = \%{$this->{request}};
    my $bld = \%{$this->{build}};

    $this->_spliturl() if $opt->{url};
    # if postdata is given, we'll set the request template to POST
    $opt->{template} =	'POST' if $opt->{postdata};
    if (defined $opt->{method})
    {
	if(lc($opt->{method}) eq 'get' ) {    	($bld->{method}, $opt->{template}) = ('GET','GET');		}
	elsif (lc($opt->{method}) eq 'post' ) {	($bld->{method}, $opt->{template}) = ('POST','POST');		}
	elsif (lc($opt->{method}) eq 'post') {	($bld->{method}, $opt->{template}) = ('TRACE','TRACE');		}
	elsif (lc($opt->{method}) eq 'options'){($bld->{method}, $opt->{template}) = ('OPTIONS','OPTIONS');	}
	else {					($bld->{method}, $opt->{template}) = ($opt->{method},'GET');	}
    }
    $opt->{template} ||=	'GET';
    $bld->{method} ||=		'GET';
    $bld->{protocol} =		$opt->{protocol}	|| 'HTTP/1.1';
    $bld->{host} =		$opt->{host}		|| $bld->{host};
    $bld->{vhost} =		$opt->{vhost}		|| $bld->{host};
    $bld->{port} =		$opt->{port}		|| $bld->{port};
    $bld->{crlf} =		$opt->{crlf}		|| "\r\n";
    $bld->{hfs} =		$opt->{hfs}		|| ': ';
    $bld->{uri} =		$opt->{uri}		if $opt->{uri};
    $bld->{rawpostdata} =	$opt->{rawpostdata}	if $opt->{rawpostdata};

    # default headers
    $bld->{headers}{'Host'} =			$bld->{vhost};
    $bld->{headers}{'Connection'} =		'close';
    $bld->{headers}{'User-Agent'} =		'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.6) Gecko/20070723 Iceweasel/2.0.0.6 (Debian-2.0.0.6-0etch1)';
    $bld->{headers}{'Accept'} =			'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5';
    $bld->{headers}{'Accept-Language'} =	'en-gb,en;q=0.7,hu;q=0.3';
    $bld->{headers}{'Accept-Charset'} =		'ISO-8859-1,utf-8;q=0.7,*;q=0.7';
    if ($opt->{'http-auth'})
    {
	my $auth = encode_base64($opt->{'http-auth'});
	$auth =~ s/[\r\n]//;
	$bld->{headers}{'Authorization'} =	'Basic '.$auth;
    }
    # settin user defined headers
    if($opt->{headers})
    {
	my @arr = @{$opt->{headers}};
	foreach my $row (@arr)
	{
	    my ($k, $v) = split /\:\s*/, $row, 2;
	    $bld->{headers}{$k} = $v;
	}
    }
    # STRICT headers
    # ezt meg kell gyogyitani
    if($opt->{'strict-headers'})
    {
#	$bld->{'strict-headers'} = $opt->{'strict-headers'};
#	$bld->{'strict-headers'} =~ s/\[n\]/\n/g;
    }
    else
    {
	$bld->{'strict-headers'} = '';
    }
}

sub _build
{
    my $this = shift;

    my $opt = \%{$this->{options}};
    my $req = \%{$this->{request}};
    my $bld = \%{$this->{build}};

    my $payload;
    if ($opt->{template} eq 'GET')
    {
	    $payload = $bld->{method}.' '.$bld->{uri}.' '.$bld->{protocol}.$bld->{crlf};
	    if( !$opt->{'no-default-headers'} )
	    {
		map {
		    $payload .= $_.$bld->{hfs}.$bld->{headers}{$_}.$bld->{crlf}
		} sort sorthdr keys %{$bld->{headers}};
	    }
	    $payload .= $bld->{'strict-headers'}.$bld->{crlf} if $opt->{'strict-headers'};
	    $payload .= $bld->{crlf};
    }
    elsif ($opt->{template} eq 'POST')
    {
	    $payload = $bld->{method}.' '.$bld->{uri}.' '.$bld->{protocol}.$bld->{crlf};
	    $bld->{headers}{'Content-Length'} = length($bld->{rawpostdata});
	    if( !$opt->{'no-default-headers'} )
	    {
		map {
		    $payload .= $_.$bld->{hfs}.$bld->{headers}{$_}.$bld->{crlf}
		} sort sorthdr keys %{$bld->{headers}};
	    }
	    $payload .= $bld->{'strict-headers'}.$bld->{crlf} if $bld->{'strict-headers'};
	    $payload .= $bld->{crlf};
	    $payload .= $bld->{rawpostdata};
    }
    elsif ($opt->{template} eq 'OPTIONS')
    {
	#TODO
	    $payload = $bld->{method}.' * '.$bld->{protocol}.$bld->{crlf};
	    if( !$opt->{'no-default-headers'} )
	    {
		map {
		    $payload .= $_.$bld->{hfs}.$bld->{headers}{$_}.$bld->{crlf}
		} sort sorthdr keys %{$bld->{headers}};
	    }
	    $payload .= $bld->{'strict-headers'}.$bld->{crlf} if $bld->{'strict-headers'};
	    $payload .= $bld->{crlf};
    }
    else
    {
	    # unknown method
	    # TODO: do something here
    }
    $this->{request} = $payload;
}

sub get
{
#    my $this = shift;
#    my $var = shift;
#    my @o = split /\./, $var;
#    # TODO
#    return $this->{$o[0]} if scalar @o == 1;
#    return $this->{$o[0]}{$o[1]} if scalar @o == 2;
#    return $this->{$o[0]}{$o[1]}{$o[2]} if scalar @o == 3;
#    return $this->{$o[0]}{$o[1]}{$o[2]}{$o[3]} if scalar @o == 4;
}

sub rq
{
    my $this = shift;
    my $var = shift;
    my @o = split /\./, $var;
    # TODO !
    return $this->{'request'}{$o[0]} if scalar @o == 1;
    return $this->{'request'}{$o[0]}{$o[1]} if scalar @o == 2;
    return $this->{'request'}{$o[0]}{$o[1]}{$o[2]} if scalar @o == 3;
    return $this->{'request'}{$o[0]}{$o[1]}{$o[2]}{$o[3]} if scalar @o == 4;
}

sub opt
{
    my $this = shift;
    my $var = shift;
    my @o = split /\./, $var;
    # TODO !
    return $this->{'options'}{$o[0]} if scalar @o == 1;
    return $this->{'options'}{$o[0]}{$o[1]} if scalar @o == 2;
    return $this->{'options'}{$o[0]}{$o[1]}{$o[2]} if scalar @o == 3;
    return $this->{'options'}{$o[0]}{$o[1]}{$o[2]}{$o[3]} if scalar @o == 4;
}


sub set
{
#    my $this = shift;
#    my $var = shift;
#    my @split /\./, $var;
#    return $this->{response};
}

sub sorthdr($$)
{
    my @arr = qw/host user-agent accept accept-charset accept-language connection/;
    my $a = -1;
    my $b = -1;
    foreach my $h (@arr)
    {
	$a++;
	last if lc($_[0]) lt $h;
    }
    foreach my $h (@arr)
    {
	$b++;
	last if lc($_[1]) lt $h;
    }
# TODO: ez igy szar
#    print "$_[0] $_[1]\n";
#    print "$a $b\n";
    return $a cmp -1;
}

# HANDLER -> SCHEME
sub _spliturl
{
    my $this = shift;

    my $opt = \%{$this->{options}};
    my $req = \%{$this->{request}};
    my $bld = \%{$this->{build}};

    my ($pre, $basic_auth, $tuff);     # tmp vars
    # Ha nem http:// vagy https-el kezddodik akkor hozzacsapjuk
    $bld->{url} = index(substr($opt->{url},4,4), '://') eq -1
	? 'http://'.$opt->{url}
	: $opt->{url};
    ($bld->{scheme}, $tuff) = split '://', $bld->{url}, 2;
    warn "Unknown protocol handler '".$bld->{handler}."'" if !in_array($bld->{scheme}, qw/http https/);
    ($bld->{host}, $bld->{uri}) = split '/', $tuff, 2;
    ($bld->{host}, $bld->{port}) = split ':', $bld->{host}, 2;
    $bld->{port} ||= (($bld->{scheme} eq 'https') ? 443 : 80);
    $bld->{uri} = defined $bld->{uri} ? '/'.$bld->{uri} : '/';
    ($bld->{uri}, $bld->{href}) = split '#', $bld->{uri}, 2;
    $bld->{href} ||= '';
    ($bld->{file}, $bld->{get_params}) = split ('\?', $bld->{uri}, 2) if $bld->{uri} and index $bld->{uri}, '?';
    bless $this;
}



####################################################################################################
# MISC
####################################################################################################

sub in_array
{
    my $v = shift;
    foreach(@_)
    {
	return 1 if $v eq $_;
    }
    return 0;
}



#
#CJ::HTTP::Response pm innentol
# 






sub _new_response
{
    my $type = shift;
    my $this = {};
    $this->{params} = {};	# parameters given by the user
    $this->{response} = shift;	# tha http response
    $this->{parsed} = {};	# 
    my %params = @_;
    while (my ($k, $v) = each %params)
    {
        $this->{'params'}{$k} = $v;
    }
    bless $this, $type;
    $this->parse;
    return $this;
}


sub get_array
{
    my $this = shift;
    my @ret;
    foreach my $k (@_)
    {
	push @ret, $this->get($k);
    }
    return @ret;
}


sub get_hash
{
    my $this = shift;
    my %ret = map { $_ => $this->get($_) } @_;
    return %ret;
}

sub _help_nemfogkelleni
{
    print '
    CJ::HTTP::Response->get(@array)
	__status line__
	status             the whole status line
	protocol           protocol
	code               http status code
	message            status message

	__headers__
	headers            headers as string
	headers-raw        -"-
	$headers           -"-
	headers-array      headers as array
	@headers           -"-
	headers-hash       headers as hash
	%headers           -"-

	__body__
	body-raw          raw body, with chunk sizes
	body-rawsize      raw body size
	body              body
	body-size         size of the body
	
	__misc__
	errors            as string
	$errors           -"-
	errors-array      as array
	@errors           -"-
	help              this stuff
';
}

sub getlofasz	
{
    my $this = shift;
    my $val = shift||'';
    # status line
    if ($val eq 'protocol')		{ return $this->{parsed}{status}{protocol};	}
	if ($val eq  'code')		{ return $this->{parsed}{status}{code};		}
	if ($val eq  'message')		{ return $this->{parsed}{status}{message};	}
	if ($val eq  'status')		{ return $this->{parsed}{status}{string};	}
	# headers
	if ($val eq  ['$headers','headers','headers.raw','headers.string'])
					{ return $this->{parsed}{headers}{string}; 	}
	if ($val eq ['@headers','headers.array'])
					{ return $this->{parsed}{headers}{array};	}
	if ($val eq  ['%headers','headers.hash'])
					{ return $this->{parsed}{headers}{hash};	}
	if ($val eq  ['headers.md5','head.md5'])
					{ return MD5->hexhash($this->{parsed}{headers}{string});	}
	# body
	if ($val eq  'body.raw')	{ return $this->{parsed}{body}{raw};	 	}
	if ($val eq  'body.raw.md5')	{ return MD5->hexhash($this->{parsed}{body}{raw});	}
	if ($val eq 'body.raw.size')	{ return $this->{parsed}{body}{rawsize}; 	}
	if ($val eq 'body')		{ return $this->{parsed}{body}{parsed}; 	}
	if ($val eq 'body.md5')		{ return MD5->hexhash($this->{parsed}{body}{parsed}); 	}
	if ($val eq 'body.size')	{ return $this->{parsed}{body}{parsedsize}; 	}
	# misc
	if ($val eq  ['$errors','errors','errors.string'])
					{ return join "\n", $this->{parsed}{errors};	 }
	if ($val eq  ['@errors','errors.array'])
					{ return $this->{parsed}{errors};	 	}
	if ($val eq  'help')		{ return $this->help;			 	}
	else		    		{
#	    $this->error("get: no such key '$val'"); 
	}
}
sub parse
{
    my $this = shift;
    my ($raw_headers, $body) = split /[\r]*\n[\r]*\n/, $this->{response}, 2;
#dump ($raw_headers, $body);
    (my $status_line, $raw_headers) = split /[\r]*\n/, $raw_headers, 2;
#dump ($status_line, $raw_headers);
    $this->{parsed}{status}{string} = $status_line;
    ( $this->{parsed}{status}{protocol}, $this->{parsed}{status}{code}, $this->{parsed}{status}{message} ) = split /\s+/,  $status_line, 3;
#dump ( $this->{parsed}{status}{protocol}, $this->{parsed}{status}{code}, $this->{parsed}{status}{message} );
    $this->{parsed}{headers}{string} = $raw_headers;
    my @headers = split /[\r]*\n/, $raw_headers;
    $this->{parsed}{headers}{array} = [@headers];
    my %headers_hash = map { my @a = split ':', $_, 2; $a[1] =~ s/^\s+//; lc($a[0]) => $a[1] } @headers;
    $this->{parsed}{headers}{hash} = \%headers_hash;
    $this->{parsed}{body}{raw} = $body;
    $this->{parsed}{body}{rawsize} = length($body);
#    print "\n'$body'\n\n";
    if(lc($this->{parsed}{headers}{hash}{'transfer-encoding'}) eq 'chunked')
    {
	
	$this->debug('CHUNKED ENCODING!');
	$this->{parsed}{body}{parsed} = $this->parse_chunked_body;
    }
    else
    {
	$this->{parsed}{body}{parsed} = $this->{parsed}{body}{raw};
    }
    $this->{parsed}{errors} = [];
    $this->{parsed}{body}{parsedsize} = length($this->{parsed}{body}{parsed});
    if (defined $this->{parsed}{headers}{hash}{'content-length'} and $this->{parsed}{headers}{hash}{'content-length'} != $this->{parsed}{body}{parsedsize})
    {
	push @{$this->{parsed}{errors}}, 'Content-length='.$this->{parsed}{headers}{hash}{'content-length'}.' body-size='.$this->{parsed}{body}{parsedsize};
    }

#    dump $this->{parsed}{errors};
#    print $this->{parsed}{body}{parsed}."\n";

    return $this;
}

sub parse_chunked_body
{
    my $this = shift;
    my $rawbody = $this->{parsed}{body}{raw};
#    $this->debug(dump $rawbody);
    my $body = '';
    while(1)
    {
	my ($cs_hex, $rest) = split /[\r]\n/, $rawbody, 2;
        my $cs_dec = sprintf("%d", hex $cs_hex);
	$this->debug(sprintf ">> hex=%-6s dec=%-6s :: restlength=%s", $cs_hex, $cs_dec, length($rest));
        $body .= substr($rest, 0, $cs_dec);
	$rawbody = substr($rest, $cs_dec + 2); # path needed a +2 nek
	$this->debug($body);
#	$this->debug($rest);
        return $body if !$cs_dec;
#    $this->{parsed}{body}{parsed}
    }
}












1;
__END__

=head1 NAME

Black::HTTP - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Black::HTTP;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Black::HTTP, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

root, E<lt>root@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by root

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
