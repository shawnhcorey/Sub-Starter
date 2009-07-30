#!/
# --------------------------------------
#
#   Title: Sub Starter
# Purpose: Creates a skeketal framework for Perl sub's.
#
#    Name: Sub::Starter
#    File: Starter.pm
# Created: July 25, 2009
#
# Copyright: Copyright 2009 by Shawn H Corey.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

# --------------------------------------
# Object
package Sub::Starter;

# --------------------------------------
# Pragmatics

require 5.8.0;

use strict;
use warnings;

use utf8;  # Convert all UTF-8 to Perl's internal representation.
binmode STDIN,  ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

# --------------------------------------
# Version
use version; our $VERSION = qv(v1.0.0);

# --------------------------------------
# Modules
use Carp;
use Data::Dumper;
use English qw( -no_match_vars ) ;  # Avoids regex performance penalty
use POSIX;
use Storable qw( dclone );

# --------------------------------------
# Configuration Parameters

my %Expand = (
  name        => sub { [ $_[0]{-name} ] },
  usage       => \&_fill_out_usage,
  parameters  => \&_fill_out_parameters,
  returns     => \&_fill_out_returns,
  definitions => \&_fill_out_definitions,
);

my %Selections = (
  are    => \&_fill_out_are,
  arenot => \&_fill_out_arenot,
  each   => \&_fill_out_each,
  first  => \&_fill_out_first,
  rest   => \&_fill_out_rest,
  list   => \&_fill_out_list,
);

my %Default_attributes = (
  -assignent         => q{''},
  -max_usage         => 0,
  -max_variable      => 0,
  -name              => '',
  -object            => '',
  -parameters        => [],
  -returns_alternate => '',
  -returns           => [],
);

my %String_escapes = (
  '\\' => '\\', # required, don't delete
  n => "\n",
  s => ' ',
  t => "\t",
);
my $String_escapes = join( '', sort keys %String_escapes );
$String_escapes =~ s{ \\ }{}gmsx;
$String_escapes = "[$String_escapes\\\\]";

my $RE_id         = qr{ [_[:alpha:]] [_[:alnum:]]* }mosx;
my $RE_scalar     = qr{ \A \$ ( $RE_id ) \z }mosx;
my $RE_array      = qr{ \A \@ ( $RE_id ) \z }mosx;
my $RE_hash       = qr{ \A \% ( $RE_id ) \z }mosx;
my $RE_scalar_ref = qr{ \A \\ \$ ( $RE_id ) \z }mosx;
my $RE_array_ref  = qr{ \A \\ \@ ( $RE_id ) \z }mosx;
my $RE_hash_ref   = qr{ \A \\ \% ( $RE_id ) \z }mosx;
my $RE_code_ref   = qr{ \A \\ \& ( $RE_id ) \z }mosx;
my $RE_typeglob   = qr{ \A \\? \* ( $RE_id ) \z }mosx;

# Make Data::Dumper pretty
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 1;
$Data::Dumper::Maxdepth = 0;

# --------------------------------------
# Variables

# --------------------------------------
# Methods

# --------------------------------------
#       Name: new
#      Usage: $starter_sub = Sub::Starter->new( ; %attributes );
#    Purpose: To create a new object.
# Parameters:  %attributes -- keys must be in %Default_attributes
#    Returns: $starter_sub -- blessed hash
#
sub new {
  my $class = shift @_;
  my $self  = dclone( \%Default_attributes );

  $class = ( ref( $class ) or $class );
  bless $self, $class;
  $self->configure( @_ );

  return $self;
}

# --------------------------------------
#       Name: configure
#      Usage: $starter_sub->configure( %attributes );
#    Purpose: To (re)set the initial key-values pairs of the object.
# Parameters: %attributes -- keys must be in %Default_attributes
#    Returns: none
#
sub configure {
  my $self       = shift @_;
  my %attributes = @_;

  for my $attribute ( keys %attributes ){
    croak "unknown attribute '$attribute'" unless exists $Default_attributes{$attribute};
    $self->{$attribute} = $attributes{$attribute};
  }
}

# --------------------------------------
#       Name: get_options
#      Usage: %attributes = $starter_sub->get_options( ; @options_names );
#    Purpose: To retrieve the current value(s) of the attributes.
# Parameters: @options_names -- each must be a key in %Default_attributes
#    Returns:    %attributes -- current settings
#
sub get_options {
  my $self       = shift @_;
  my @attributes = @_;
  my %attributes = ();

  if( @attributes ){
    for my $attribute ( @attributes ){
      $attributes{$attribute} = $self->{$attribute} if exists $Default_attributes{$attribute};
    }
  }else{
    for my $attribute ( keys %Default_attributes ){
      $attributes{$attribute} = $self->{$attribute};
    }
  }

  return %attributes;
}

# --------------------------------------
#       Name: _parse_variable
#      Usage: %attr = _parse_variable( $parsed, $var );
#    Purpose: Find the attributes of a variable.
# Parameters: $parsed -- scratch pad for results
#                $var -- variable to parse
#    Returns:   %attr -- attributes of the variable
#
sub _parse_variable {
  my $parsed = shift @_;
  my $var    = shift @_;
  my $name   = '';
  my %attr   = ();

  $attr{-usage} = $var;
  $parsed->{-max_usage} = length $var if $parsed->{-max_usage} < length $var;

  if( $var =~ $RE_scalar ){
    $name = $1;
    $attr{-type} = 'scalar';
    $attr{-variable} = $attr{-usage};
  }elsif( $var =~ $RE_array ){
    $name = $1;
    $attr{-type} = 'array';
    $attr{-variable} = $attr{-usage};
  }elsif( $var =~ $RE_hash ){
    $name = $1;
    $attr{-type} = 'hash';
    $attr{-variable} = $attr{-usage};
  }elsif( $var =~ $RE_scalar_ref ){
    $name = $1; # . '_sref';
    $attr{-type} = 'scalar_ref';
    $attr{-variable} = '$' . $name;
  }elsif( $var =~ $RE_array_ref ){
    $name = $1; # . '_aref';
    $attr{-type} = 'array_ref';
    $attr{-variable} = '$' . $name;
  }elsif( $var =~ $RE_hash_ref ){
    $name = $1; # . '_href';
    $attr{-type} = 'hash_ref';
    $attr{-variable} = '$' . $name;
  }elsif( $var =~ $RE_code_ref ){
    $name = $1; # . '_cref';
    $attr{-type} = 'code_ref';
    $attr{-variable} = '$' . $name;
  }elsif( $var =~ $RE_typeglob ){
    $name = $1; # . '_gref';
    $attr{-type} = 'typeglob';
    $attr{-variable} = '$' . $name;
  }else{
    croak "unknown variable type: $var";
  }

  my $length = length( $name ) + 1;
  $parsed->{-max_variable} = $length if $parsed->{-max_variable} < $length;
  return %attr;
}

# --------------------------------------
#       Name: _parse_returns
#      Usage: $sub_starter->_parse_returns( $parsed, $returns_part );
#    Purpose: Parse the sub's return variables
# Parameters:       $parsed -- storage hash
#             $returns_part -- part of the usage statment before the assignment
#    Returns: none
#
sub _parse_returns {
  my $parsed  = shift @_;
  my $returns = shift @_;
  my $list_var = 0;
  my %seen = ();

  return unless length $returns;

  if( $returns =~ s{ \+\= \z }{}msx ){
    $parsed->{-assignent} = 0;
  }else{
    $returns =~ s{ \= \z }{}msx;
  }

  if( $returns =~ m{ \A ( ([^\|]*) \| )? \( (.*?) \) \z }msx ){
    $parsed->{-returns_alternate} = $2;
    my $list = $3;

    if( $parsed->{-returns_alternate} ){
      $parsed->{-returns_alternate} = { _parse_variable( $parsed, $parsed->{-returns_alternate} ) };
      croak "alternative return variable is not a scalar" if $parsed->{-returns_alternate}{-type} ne 'scalar';
    }

    for my $var ( split m{ \, }msx, $list ){
      if( $seen{$var} ++ ){
        croak "Return parameter $var repeated";
      }
      my %attr = _parse_variable( $parsed, $var );
      push @{ $parsed->{-returns} }, { %attr };
      if( $attr{-type} eq 'array' or $attr{-type} eq 'hash' ){
        croak "array or hash may only occur at end of returns list" if $list_var ++;
      }
    }
  }elsif( $returns =~ m{ \A ([^\|]*) \| (.*?) \z }msx ){
    $parsed->{-returns_alternate} = $1;
    my $var = $2;

    $parsed->{-returns_alternate} = { _parse_variable( $parsed, $parsed->{-returns_alternate} ) };
    croak "alternative return variable is not a scalar" if $parsed->{-returns_alternate}{-type} ne 'scalar';
    if( $seen{$var} ++ ){
      croak "Return parameter $var repeated";
    }
    my %attr = _parse_variable( $parsed, $var );
    push @{ $parsed->{-returns} }, { %attr };
  }else{
    if( $seen{$returns} ++ ){
      croak "Return parameter $returns repeated";
    }
    my %attr = _parse_variable( $parsed, $returns );
    push @{ $parsed->{-returns} }, { %attr };
  }
  return;
}

# --------------------------------------
#       Name: _parse_parameters
#      Usage: _parse_parameters( $parsed, $param_part );
#    Purpose: Break the parameters into variables and store them.
# Parameters:     $parsed -- storage hash
#             $param_part -- part of the usage statment including optional parameters
#    Returns: none
#
sub _parse_parameters {
  my $parsed     = shift @_;
  my $param_part = shift @_;
  my $opt_params = '';
  my $list_var = 0;
  my %seen = ();

  if( $param_part =~ m{ \A ([^;]*) \; (.*) }msx ){
    $param_part = $1;
    $opt_params = $2;
  }

  for my $param ( split m{ \, }msx, $param_part ){
    if( $seen{$param} ++ ){
      die "Parameter $param repeated\n";
    }
    my %attr = _parse_variable( $parsed, $param );
    push @{ $parsed->{-parameters} }, { %attr };
    if( $attr{-type} eq 'array' or $attr{-type} eq 'hash' ){
      die "array or hash may only occur at end of parameter list" if $list_var ++;
    }
  }

  for my $param ( split m{ \, }msx, $opt_params ){
    if( $seen{$param} ++ ){
      die "Parameter $param repeated\n";
    }
    my %attr = _parse_variable( $parsed, $param );
    push @{ $parsed->{-parameters} }, { optional=>1, %attr };
    if( $attr{-type} eq 'array' or $attr{-type} eq 'hash' ){
      die "array or hash may only occur at end of parameter list" if $list_var ++;
    }
  }

  return;
}

# --------------------------------------
#       Name: parse
#      Usage: $sub_starter->parse( $usage_statement );
#    Purpose: Parse a usage statement and store its contents.
# Parameters: $usage_statement -- See POD for details
#    Returns: none
#
sub parse {
  my $self            = shift @_;
  my $usage_statement = shift @_;
  my $usage = $usage_statement;

  # create a scratch pad
  my $parsed = dclone( \%Default_attributes );

  # clean up for easier processing
  $usage =~ s{ \s+ }{}gmsx;
  $usage =~ s{ \)? \;? \z }{}msx;

  # find returns via an assignment symbol
  my $returns_part = '';
  my $func_part = $usage;
  if( $usage =~ m{ \A ( [^=]* \= ) (.*) }msx ){
    $returns_part = $1;
    $func_part = $2;
  }
  if( $func_part =~ m{ = }msx ){
    croak "Multiple assignments in usage statment";
  }

  # get the name and possible object
  my $name_part = $func_part;
  my $param_part = '';
  if( $name_part =~ m{ \A ( [^()]* ) \( ( .*? ) \)? \z }msx ){
    $name_part = $1;
    $param_part = $2;
  }
  if( $name_part =~ s{ \A (.*?) \-\> }{}msx ){
    $parsed->{-object} =  $1;
    $parsed->{-max_variable} = 5;
  }
  $name_part =~ s{ \A \& }{}msx;
  $parsed->{-name} = $name_part;

  # parse the rest
  _parse_returns( $parsed, $returns_part );
  _parse_parameters( $parsed, $param_part );

  # set the values
  $self->configure( %$parsed );

  # print "\n\nSub::Starter->parse(): ", Dumper $usage_statement, $self;
  return;
}

# --------------------------------------
#       Name: _fill_out_usage
#      Usage: \@text = _fill_out_usage( $self );
#    Purpose: Create a usage statement
# Parameters:   $self -- parameters of the sub
#    Returns:  \@text -- the usage statement in an anonynous array
#
sub _fill_out_usage {
  my $self   = shift @_;
  my $part   = shift @_;
  my $format = shift @_;
  my $text   = '';

  # alternative returns
  if( ref $self->{-returns_alternate} ){
    $text = $self->{-returns_alternate}{-usage} . ' | ';
  }

  # do returns
  if( @{ $self->{-returns} } > 0 ){
    $text .= '( ' if @{ $self->{-returns} } > 1;
    my @list = ();
    for my $return ( @{ $self->{-returns} } ){
      push @list, $return->{-usage};
    }
    $text .= join( ', ', @list ) . ' ';
    $text .= ') ' if @{ $self->{-returns} } > 1;
    if( $self->{-assignent} eq '0' ){
      $text .= '+= ';
    }else{
      $text .= '= ';
    }
  }

  # do object
  if( length $self->{-object} ){
    $text .= $self->{-object} . '->';
  }

  # do name
  $text .= $self->{-name} . '(';

  # do parameters
  if( @{ $self->{-parameters} } > 0 ){
    $text .= ' ';
    my @list = ();
    my @optional = ();
    for my $parameter ( @{ $self->{-parameters} } ){
      if( $parameter->{optional} ){
        push @optional, $parameter->{-usage};
      }else{
        push @list, $parameter->{-usage};
      }
    }
    $text .= join( ', ', @list );
    if( @optional ){
      $text .= '; ' . join( ', ', @optional );
    }
    $text .= ' ';
  }

  # finish
  $text .= ');';

  return [ $text ];
}

# --------------------------------------
#       Name: _fill_out_are
#      Usage: \@text = _fill_out_are( $max_len, $string, @list );
#    Purpose: Determine if there is a list
# Parameters: $string -- A string to return
#               @list -- a list to test
#    Returns:  \@text -- array of the string or undef
#
sub _fill_out_are {
  my $max_len = shift @_;
  my $string = shift @_;
  my @list   = @_;

  return unless @list;

  if( defined $string ){
    $string =~ s{ \\ ($String_escapes) }{$String_escapes{$1}||$1}egmsx;
  }else{
    $string = '';
  }

  return [ $string ];
}

# --------------------------------------
#       Name: _fill_out_arenot
#      Usage: \@text = _fill_out_arenot( $max_len, $string, @list );
#    Purpose: Determine if there isn't a list
# Parameters: $string -- A string to return
#               @list -- a list to test
#    Returns:  \@text -- array of the string or undef
#
sub _fill_out_arenot {
  my $max_len = shift @_;
  my $string = shift @_;
  my @list   = @_;

  return if @list;

  if( defined $string ){
    $string =~ s{ \\ ($String_escapes) }{$String_escapes{$1}||$1}egmsx;
  }else{
    $string = '';
  }

  return [ $string ];
}

# --------------------------------------
#       Name: _fill_out_each
#      Usage: \@text = _fill_out_each( $max_len, $format, @list );
#    Purpose: Apply the format to all items in the list.
# Parameters: $format -- How to display the items
#               @list -- The list
#    Returns:  \@text -- Formatted items
#
sub _fill_out_each {
  my $max_len = shift @_;
  my $format = shift @_;
  my @list   = @_;
  my $text   = undef;

  return unless @list;

  $format =~ s{ \\ ($String_escapes) }{$String_escapes{$1}||$1}egmsx;

  # print 'each: ', Dumper $format, \@list;
  if( $format =~ m{ \* }msx ){
    $text = [ map { sprintf( $format, $max_len, $_ ) } @list ];
  }else{
    $text = [ map { sprintf( $format, $_ ) } @list ];
  }

  return $text;
}

# --------------------------------------
#       Name: _fill_out_first
#      Usage: \@text = _fill_out_first( $max_len, $format, @list );
#    Purpose: Apply the format to the first item of the list.
# Parameters: $format -- How to display the items
#               @list -- The list
#    Returns:  \@text -- Formatted items
#
sub _fill_out_first {
  my $max_len = shift @_;
  my $format = shift @_;
  my @list   = @_;

  return unless @list;

  return _fill_out_each( $max_len, $format, $list[0] );
}

# --------------------------------------
#       Name: _fill_out_rest
#      Usage: \@text = _fill_out_rest( $max_len, $format, @list );
#    Purpose: Apply the format to all but the first item of the list.
# Parameters: $format -- How to display the items
#               @list -- The list
#    Returns:  \@text -- Formatted items
#
sub _fill_out_rest {
  my $max_len = shift @_;
  my $format = shift @_;
  my @list   = @_;

  return unless @list;

  return _fill_out_each( $max_len, $format, @list[ 1 .. $#list ] );
}

# --------------------------------------
#       Name: _fill_out_list
#      Usage: \@text = _fill_out_list( $max_len, $separator, @list );
#    Purpose: Create a string of the list
# Parameters: $separator -- What to join with
#                  @list -- List ot join
#    Returns:     \@text -- Array of the string
#
sub _fill_out_list {
  my $max_len   = shift @_;
  my $separator = shift @_ || '';
  my @list      = @_;

  return [ join( $separator, @list ) ];
}

# --------------------------------------
#       Name: _fill_out_parameters
#      Usage: \@text = _fill_out_parameters( $self, $selection, $format );
#    Purpose: Create a list of formatted, selected parameters.
# Parameters:      $self -- contains parameter list
#             $selection -- a subset of the parameters
#                $format -- how to display
#    Returns:     \@text -- formatted, selected parameters
#
sub _fill_out_parameters {
  my $self      = shift @_;
  my $selection = shift @_;
  my $format    = shift @_;

  my @list = map { $_->{-usage} } @{ $self->{-parameters} };
  #print 'parameters: ',Dumper \@list;

  if( exists $Selections{$selection} ){
    return &{ $Selections{$selection} }( $self->{-max_usage}, $format, @list );
  }else{
    carp "no selection for '$selection', skipped";
    return;
  }
}

# --------------------------------------
#       Name: _fill_out_returns_expression
#      Usage: \@text = _fill_out_returns_expression( $self );
#    Purpose: Create the return expression for tits statement.
# Parameters:  $self -- essential data
#    Returns: \@text -- string in an array
#
sub _fill_out_returns_expression {
  my $self = shift @_;
  my $text = ' ';

  return [''] unless @{ $self->{-returns} };

  # print 'expression: ', Dumper $self;
  my $returns = '';
  if( @{ $self->{-returns} } > 1 ){
    $returns = '( ' . join( ', ', map { $_->{-variable} } @{ $self->{-returns} } ) . ' )';
  }else{
    $returns = $self->{-returns}[0]{-variable};
  }

  if( $self->{-returns_alternate} ){
    $text .= "wantarray ? $returns : $self->{-returns_alternate}{-variable}";
  }else{
    $text .= $returns;
  }

  return [ $text ];
}

# --------------------------------------
#       Name: _fill_out_returns
#      Usage: \@text = _fill_out_returns( $self, $selection, $format );
#    Purpose: Create a list of formatted, selected returns.
# Parameters:      $self -- contains returns list
#             $selection -- a subset of the returns
#                $format -- how to display
#    Returns:     \@text -- formatted, selected returns
#
sub _fill_out_returns {
  my $self      = shift @_;
  my $selection = shift @_;
  my $format    = shift @_;
  my $text      = [];

  my @list = map { $_->{-usage} } @{ $self->{-returns} };
  if( $self->{-returns_alternate} ){
    unshift @list, $self->{-returns_alternate}{-usage};
  }
  #print 'returns: ',Dumper \@list;

  if( $selection eq 'expression' ){
    return _fill_out_returns_expression( $self );
  }elsif( exists $Selections{$selection} ){
    return &{ $Selections{$selection} }( $self->{-max_usage}, $format, @list );
  }else{
    carp "no selection for '$selection', skipped";
    return;
  }

  return $text;
}

# --------------------------------------
#       Name: _fill_out_definitions
#      Usage: \@text = _fill_out_definitions( $self, $format );
#    Purpose: Create a list of formatted, selected definitions.
# Parameters:      $self -- contains parameter and returns list
#                $format -- how to display
#    Returns:     \@text -- formatted, selected definitions
#
sub _fill_out_definitions {
  my $self      = shift @_;
  my $format    = shift @_;
  my @list      = ();
  my $text      = [];
  my %seen = ();

  # print 'self: ', Dumper $self;

  $format =~ s{ \\ ($String_escapes) }{$String_escapes{$1}||$1}egmsx;

  # do parameters
  if( $self->{-object} ){
    push @list, {
      -name     => 'self',
      -variable => '$self',
      -type     => 'scalar',
      -usage    => '$self'
    };
  }
  push @list, @{ $self->{-parameters} };

  # print 'parameters @list ', Dumper \@list, $format;
  for my $item ( @list ){
    next if $seen{$item->{-variable}} ++;
    my $value = 'shift @_';
    $value .= " || $self->{-assignent}" if $item->{optional};
    if( $item->{-type} eq 'array' || $item->{-type} eq 'hash' ){
      $value = '@_';
    }
    if( $format =~ m{ \* }msx ){
      push @$text, sprintf( $format, $self->{-max_variable}, $item->{-variable}, $value );
    }else{
      push @$text, sprintf( $format, $item->{-variable}, $value );
    }
  }

  # do returns
  @list = ();
  if( $self->{-returns_alternate} ){
    push @list, $self->{-returns_alternate};
  }
  push @list, @{ $self->{-returns} };

  # print 'returns @list ', Dumper \@list;
  for my $item ( @list ){
    next if $seen{$item->{-variable}} ++;
    my $value = $self->{-assignent};
    if( $item->{-type} eq 'scalar' ){
      # value already set
    }elsif( $item->{-type} eq 'array' || $item->{-type} eq 'hash' ){
      $value = '()';
    }elsif( $item->{-type} eq 'array_ref' ){
      $value = '[]';
    }elsif( $item->{-type} eq 'hash_ref' ){
      $value = '{}';
    }else{
      $value = 'undef';
    }
    if( $format =~ m{ \* }msx ){
      push @$text, sprintf( $format, $self->{-max_variable}, $item->{-variable}, $value );
    }else{
      push @$text, sprintf( $format, $item->{-variable}, $value );
    }
  }

  return $text;
}

# --------------------------------------
#       Name: fill_out
#      Usage: $text = $sub_starter->fill_out( \@template );
#    Purpose: Fill out the template with the current parameters
# Parameters: \@template -- List of lines with replacements
#    Returns:      $text -- resulting text
#
sub fill_out {
  my $self     = shift @_;
  my $template = shift @_;
  my $text     = '';

  for my $template_line ( @$template ){
    my $line = $template_line;  # copy to modify

    if( $line =~ m{ \A (.*?) \e\[1m \( ([^\)]*) \) \e\[0?m (.*) }msx ){
      my $front = $1;
      my $item = $2;
      my $back = $3;
      my ( $directive, @arguments ) = split m{ \s+ }msx, $item;

      my $expansion; # array reference
      if( exists $Expand{$directive} ){
        $expansion = &{ $Expand{$directive} }( $self, @arguments );
      }else{
        carp "no expansion for '$directive'";
        next;
      }

      for my $expanded ( @$expansion ){
        $text .= $front . $expanded . $back;
      }

    }else{
      $text .= $line;
    }
  }

  return $text;
}

1;
__DATA__
__END__

=head1 NAME

Sub::Starter - Creates a skeketal framework for Perl sub's.

=head1 VERSION

This document refers to Sub::Starter version v1.0.0

=head1 SYNOPSIS

  use Sub::Starter;

=head1 DESCRIPTION

TBD

=head1 METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-Sub::Starter at rt.cpan.org>, or through the web
interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Sub::Starter>.
I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Sub::Starter

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Sub-Starter>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Sub-Starter>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Sub-Starter>

=item * Search CPAN

L<http://search.cpan.org/dist/Sub-Starter>

=back

=head1 SEE ALSO

=head1 ORIGINAL AUTHOR

Shawn H Corey  C<< <SHCOREY at cpan.org> >>

=head2 Contributing Authors

(Insert your name here if you modified this program or its documentation.
 Do not remove this comment.)

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENCES

Copyright 2009 by Shawn H Corey.  All rights reserved.

=head2 Software Licence

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

=head2 Document Licence

Permission is granted to copy, distribute and/or modify this document under the
terms of the GNU Free Documentation License, Version 1.2 or any later version
published by the Free Software Foundation; with the Invariant Sections being
ORIGINAL AUTHOR, COPYRIGHT & LICENCES, Software Licence, and Document Licence.

You should have received a copy of the GNU Free Documentation Licence
along with this document; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

=cut
