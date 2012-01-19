package Black::HTTP;

use 5.010001;
use strict;
use warnings;

# ezek nem biztos hogy kellenek, Response depjei
use constant 'DEBUG' => 0;
use constant 'ERRORS' => 0;
use Data::Dump qw-dump-;
use Switch;
use MD5;

# Request depjei

# switchet nem hasznalunk mert sourcefilterrel van osszerakva
# use Switch;

use MIME::Base64;

#use constant 'DEBUG' => 0;
#use constant 'ERRORS' => 0;

# ezt nem akarjuk
# no strict 'refs'; 
                              


require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Black::HTTP ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.

our %EXPORT_TAGS = (
    'all' => [ qw( ) ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

# Na az van hogy osszemasoltam a ket modult, ugyhogy omlesztve vannak itt a szarok.
# ebbol kene egy tiszta verziot osszehozni






#
# CJ::HTTP::Request pm copy paste
#



sub getopts
{
    my $self = shift;
    my @ARGT;
    my %ret;
    my %long = (
	#long			short, shifts, description
	# DEBUGGING AND ETC
	'debug' =>		['d',	0,	'turn on debug'],
	# REQUEST LINE
	'url' =>		['u',	1,	'set url'],
	'method' =>		['M',	1,	'set request[ed] method'],
	'uri' =>		['U',	1,	'set arbitary request URI'],
	'protocol' =>		['P',	1,	'set request protocol'],
	# HEADERS
	'vhost' =>		['v',	1,	'vhost, set Host header'],
	'headers' =>		['H',	1,	'set Header'],
	'no-default-headers' =>	['N',	0,	'dont set default Headers'],
	'strict-headers' =>	['S',	1,	'set Strict Header'],
	'crlf' =>		['',	1,	'sortores. defaults to \r\n'],
	'hfs' =>		['',	1,	'header field separator. defaults to ": "'],
	'http-auth' =>		['A',	1,	'basic http auth'],
	'help' =>		['',	0,	'dump help'],
	'postdata' =>		['p',	1,	'post data'],
	'rawpostdata' =>	['r',	1,	'raw post data'],
    );
#	dump \%long;
#	short map
    my %short = map { ${$long{$_}}[0] => $_ } keys %long;
#	dump \%short;
    while (my $opt = shift @ARGV)
    {
	my $o;
	if (substr ($opt, 0, 2) eq '--')
	{
	    # HANDLE LONG params
	    $o = substr $opt, 2;
	    my @v;
	    if(!$long{$o})
	    {
		CJ::HTTP::Request::getopts_error($opt);
		push @ARGT, $opt;
	    }
	    elsif(${$long{$o}}[1] == 0)
	    {
		$ret{$o} = 1;
	    }
	    elsif(${$long{$o}}[1] == 1)
	    {
		$ret{$o} = shift @ARGV;
	    }
	    else
	    {
		for(my $i=0;$i<${$long{$o}}[1];$i++)
		{
		    push @v, shift @ARGV;
		}
		$ret{$o} = [@v];
	    }
	}
	elsif (substr ($opt, 0, 1) eq '-')
	{
	    $o = substr $opt, 1;
	    if(!$short{$o})
	    {
		CJ::HTTP::Request::getopts_error($opt);
		push @ARGT, $opt;
	    }
	    else
	    {
		unshift @ARGV, '--'.$short{$o}; 
	    }
	}
	else
	{
	    CJ::HTTP::Request::getopts_error($opt);
	    push @ARGT, $opt;
	}
    }
    @ARGV = @ARGT;
    # help/usage/bullshit
    if(CJ::HTTP::Request::in_array('help', keys %ret))
    {
	print STDERR "Options\n";
        foreach my $k (keys %long)
	{
	    my $o_l = '--'.$k;
	    my $o_s = ${$long{$k}}[0]?'-'.${$long{$k}}[0]:'  ';
	    my $o_d = ${$long{$k}}[2];
	    printf STDERR "\t%s %-16s %s\n", $o_s, $o_l, $o_d;
	}
	exit;
	print STDERR "\n";
    }
    return %ret;
}

sub getopts_error
{
    return if !ERRORS;
    my $opt = shift;
    CJ::HTTP::Request::error("getopts Pushing '$opt' to \@ARGV");
}
sub error
{
    return if !ERRORS;
    my $msg = shift;
    print STDERR "+ CJ::HTTP::Request->$msg\n";
}

sub debug
{
    return if !DEBUG;
    my $this = shift;
    my $var = shift;
    my $val = eval($var)||'';
    printf STDERR "+ \e[1;34mCJ::HTTP::Request->debug: \e[1;36m %-36s : \e[1;33m'%s'\e[0;39m\n", $var, $val;
}


sub new
{
    my $type = shift;
    my $this = {};
    $this->{'params'} = {};	# parameters given by the user
    $this->{'request'} = {};	# request object
    $this->{'response'} = {};	# tha http request
    my %params = @_;
    while (my ($k, $v) = each %params)
    {
	$this->{'params'}{$k} = $v;
    }
    bless $this, $type;
    $this->prepare();
    return $this;
}




sub prepare
{
    my $this = shift;
    
    $this->spliturl() if $this->{params}{url};

    $this->{request}{template} =	'POST' if $this->{request}{postdata};
    if (defined $this->{params}{method})
    {
	switch(lc($this->{params}{method}))
	{
	    case 'get' {	($this->{request}{method}, $this->{params}{template}) =	('GET','GET');		}
	    case 'post' {	($this->{request}{method}, $this->{params}{template}) =	('POST','POST');	}
	    case 'post' {	($this->{request}{method}, $this->{params}{template}) =	('TRACE','TRACE');	}
	    case 'options' {	($this->{request}{method}, $this->{params}{template}) =	('OPTIONS','OPTIONS');	}
	    else {		($this->{request}{method}, $this->{params}{template}) =	($this->{params}{method},'GET');	}
	}
    }
    $this->{params}{template} ||=	'GET';
    $this->{request}{method} ||=	'GET';
    $this->{request}{protocol} =	$this->{params}{protocol}	|| 'HTTP/1.1';
    $this->{request}{host} =		$this->{params}{host}		|| $this->{request}{host};
    $this->{request}{vhost} =		$this->{params}{vhost}		|| $this->{request}{host};
    $this->{request}{port} =		$this->{params}{port}		|| $this->{request}{port};
    $this->{request}{crlf} =		$this->{params}{crlf}		|| "\r\n";
    $this->{request}{hfs} =		$this->{params}{hfs}		|| ': ';
    $this->{request}{uri} =		$this->{params}{uri}		if $this->{params}{uri};
    $this->{request}{rawpostdata} =	$this->{params}{rawpostdata}	if $this->{params}{rawpostdata};

    # default headers for FireFox
    $this->{request}{headers}{'Host'} =			$this->{request}{vhost};
    $this->{request}{headers}{'Connection'} =		'close';
    $this->{request}{headers}{'User-Agent'} =		'Mozilla/5.0 no-gzip (X11; U; Linux i686; en-US; rv:1.8.1.6) Gecko/20070723 Iceweasel/2.0.0.6 (Debian-2.0.0.6-0etch1)';
    $this->{request}{headers}{'Accept'} =		'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5';
    $this->{request}{headers}{'Accept-Language'}=	'en-gb,en;q=0.7,hu;q=0.3';
    $this->{request}{headers}{'Accept-Charset'}=	'ISO-8859-1,utf-8;q=0.7,*;q=0.7';
    $this->{request}{headers}{'Accept-Encoding'}=	'identity;q=1';
    if ($this->{params}{'http-auth'})
    {
	my $auth = encode_base64($this->{params}{'http-auth'});
	$auth =~ s/[\r\n]//;
	$this->{request}{headers}{'Authorization'}=	'Basic '.$auth;
    }
    # settin user defined headers
    if($this->{params}{headers})
    {
	my @arr = split /\[n\]/, $this->{params}{headers};
	foreach my $row (@arr)
	{
	    my ($k, $v) = split /\:\s*/, $row, 2;
	    $this->{request}{headers}{$k} = $v;
	}
    }
    # STRICT headers
    if($this->{params}{'strict-headers'})
    {
	$this->{request}{'strict-headers'} = $this->{params}{'strict-headers'};
	$this->{request}{'strict-headers'} =~ s/\[n\]/\n/g;
    }
    else
    {
	$this->{request}{'strict-headers'} = '';
    }
    $this->build();
}

sub build
{
    my $this = shift;
    my $payload;
    switch ($this->{params}{template})
    {
	case 'GET'
	{
	    $payload = $this->{request}{method}.' '.$this->{request}{uri}.' '.$this->{request}{protocol}.$this->{request}{crlf};
	    if( !$this->{params}{'no-default-headers'} )
	    {
		map { $payload .= $_.$this->{request}{hfs}.$this->{request}{headers}{$_}.$this->{request}{crlf} } sort sorthdr keys %{$this->{request}{headers}};
	    }
	    $payload .= $this->{request}{'strict-headers'}.$this->{request}{crlf} if $this->{request}{'strict-headers'};
	    $payload .= $this->{request}{crlf};
	}
	case 'POST'
	{
	    $payload = $this->{request}{method}.' '.$this->{request}{uri}.' '.$this->{request}{protocol}.$this->{request}{crlf};
	    $this->{request}{headers}{'Content-Length'} = length($this->{request}{rawpostdata});
	    if( !$this->{params}{'no-default-headers'} )
	    {
		map { $payload .= $_.$this->{request}{hfs}.$this->{request}{headers}{$_}.$this->{request}{crlf} } sort sorthdr keys %{$this->{request}{headers}};
	    }
	    $payload .= $this->{request}{'strict-headers'}.$this->{request}{crlf} if $this->{request}{'strict-headers'};
	    $payload .= $this->{request}{crlf};
	    $payload .= $this->{request}{rawpostdata};
	}
	case 'OPTIONS'
	{
	    $payload = $this->{request}{method}.' * '.$this->{request}{protocol}.$this->{request}{crlf};
	    if( !$this->{params}{'no-default-headers'} )
	    {
		map { $payload .= $_.$this->{request}{hfs}.$this->{request}{headers}{$_}.$this->{request}{crlf} } sort sorthdr keys %{$this->{request}{headers}};
	    }
	    $payload .= $this->{request}{'strict-headers'}.$this->{request}{crlf} if $this->{request}{'strict-headers'};
	    $payload .= $this->{request}{crlf};
	}
	case 'TRACE'
	{
	    $payload = $this->{request}{method}.' '.$this->{request}{uri}.' '.$this->{request}{protocol}.$this->{request}{crlf};
	    if( !$this->{params}{'no-default-headers'} )
	    {
		map { $payload .= $_.$this->{request}{hfs}.$this->{request}{headers}{$_}.$this->{request}{crlf} } sort sorthdr keys %{$this->{request}{headers}};
	    }
	    $payload .= $this->{request}{'strict-headers'}.$this->{request}{crlf} if $this->{request}{'strict-headers'};
	    $payload .= $this->{request}{crlf};
	}
	else
	{
	    # unknown method
	}
    }
    $this->{response} = $payload;
}

sub get
{
    my $this = shift;
    return $this->{response};
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


sub spliturl
{
    my $this = shift;
    # $this->{request}{}
#    my ($use_ssl, $uri_handler, $host, $port, $uri, $path, $file, $params, $href);    # return vars
    my ($pre, $basic_auth,$tuff);     # tmp vars
    # Ha nem http:// vagy https-el kezddodik akkor hozzacsapjuk
    $this->{request}{url} = index(substr($this->{params}{url},4,4), '://') eq -1
	?'http://'.$this->{params}{url}
	:$this->{params}{url};
    $this->debug('$this->{params}{url}');
    
    ($this->{request}{handler}, $tuff) = split '://', $this->{request}{url}, 2;
    $this->debug('$this->{request}{handler}');

    warn "Unknown protocol handler '".$this->{request}{handler}."'" if !CJ::HTTP::Request::in_array($this->{request}{handler}, qw/http https/);
    ($this->{request}{host}, $this->{request}{uri}) = split '/', $tuff, 2;
    $this->debug('$this->{request}{host}');
    $this->debug('$this->{request}{uri}');

    ($this->{request}{host}, $this->{request}{port}) = split ':', $this->{request}{host}, 2;
    $this->debug('$this->{request}{host}');
    $this->{request}{port} ||= $this->{request}{handler} eq 'https' ? 443 : 80;
    $this->debug('$this->{request}{port}');

    $this->{request}{uri} = defined $this->{request}{uri} ? '/'.$this->{request}{uri} : '/';
    $this->debug('$this->{request}{uri}');

    ($this->{request}{uri}, $this->{request}{href}) = split '#', $this->{request}{uri}, 2;
    $this->debug('$this->{request}{uri}');
    $this->debug('$this->{request}{href}');

    $this->{request}{href} ||= '';
    $this->debug('$this->{request}{href}');

    ($this->{request}{file}, $this->{request}{get_params}) = split ('\?', $this->{request}{uri}, 2) if $this->{request}{uri} and index $this->{request}{uri}, '?';
#    print STDERR "\n";
    $this->debug('$this->{request}{uri}');
    $this->debug('$this->{request}{get_params}');
#    $this->{request}{href} ||= '';
#    $this->debug('$this->{request}{href}');
    
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




sub error
{
    return if !ERRORS;
    my $this = shift;
    my $msg = shift;
    print STDERR "+ CJ::HTTP::Response->$msg\n";
}

sub debug_var
{
    return if !DEBUG;
    my $this = shift;
    my $var = shift;
    my $val = eval($var)||'';
    printf STDERR "+ \e[1;34mCJ::HTTP::Response->debug_var: \e[1;36m %-36s : \e[1;33m'%s'\e[0;39m\n", $var, $val;
}

sub debug
{
    return if !DEBUG;
    my $this = shift;
    my $msg = shift;
    printf STDERR "+ \e[1;34mCJ::HTTP::Response->debug: \e[1;36m: \e[1;33m'%s'\e[0;39m\n", $msg;
}





sub new
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


sub in_array
{
    my $v = shift;
    foreach(@_)
    {
	return 1 if $v eq $_;
    }
    return 0;
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

sub help
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

sub get
{
    my $this = shift;
    my $val = shift||'';
    switch($val)
    {
	# status line
	case 'protocol'
			{ return $this->{parsed}{status}{protocol};	}
	case 'code'
			{ return $this->{parsed}{status}{code};		}
	case 'message'
			{ return $this->{parsed}{status}{message};	}
	case 'status'
			{ return $this->{parsed}{status}{string};	}
	# headers
	case ['$headers','headers','headers.raw','headers.string']
			{ return $this->{parsed}{headers}{string}; 	}
	case ['@headers','headers.array']
			{ return $this->{parsed}{headers}{array};	}
	case ['%headers','headers.hash']
			{ return $this->{parsed}{headers}{hash};	}
	case ['headers.md5','head.md5']
			{ return MD5->hexhash($this->{parsed}{headers}{string});	}
	# body
	case 'body.raw'
			{ return $this->{parsed}{body}{raw};	 	}
	case 'body.raw.md5'
			{ return MD5->hexhash($this->{parsed}{body}{raw});	}
	case 'body.raw.size'
			{ return $this->{parsed}{body}{rawsize}; 	}
	case 'body'
			{ return $this->{parsed}{body}{parsed}; 	}
	case 'body.md5'
			{ return MD5->hexhash($this->{parsed}{body}{parsed}); 	}
	case 'body.size'
			{ return $this->{parsed}{body}{parsedsize}; 	}
	# misc
	case ['$errors','errors','errors.string']
			{ return join "\n", $this->{parsed}{errors};	 }
	case ['@errors','errors.array']
			{ return $this->{parsed}{errors};	 	}
	case 'help'
			{ return $this->help;			 	}
	else
	    		{ $this->error("get: no such key '$val'"); 	}
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
# Below is stub documentation for your module. You'd better edit it!

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
