
#######################################################################
#######################################################################
package Tk::Peapod::Parser;
#######################################################################
#######################################################################

use strict;
use warnings;
use Data::Dumper;

use Pod::Simple;

our @ISA;
push(@ISA,'Pod::Simple');

#######################################################################

my %start_new_line_for_element =
	(
	head => 1,
	for => 1,
	Document => 1,
	Para => 1,
	Verbatim => 1,

	'over_bullet' => 0,
	'item_bullet' => 1,

	'over_text' => 0,
	'item_text' => 1,

	'I' => 0,	# italics
	'B' => 0,	# bold
	'C' => 0,	# code

	'L' => 0,	# hyperlink

# hyperlinks can have 1 of 3 formats
# L<name> where name is another module, L<Net::Ping>
# L<name/sec> or L<name/"sec"> where sec refers to 
#		a section in the named module
# 		L<perlsyn/"For Loops">
# L</sec> a link to a section in this current manual

	

	);

#######################################################################
sub new
{
 my ($class) = @_;
 my $parser = $class->SUPER::new();
 $parser->{_marker_counts}={};
 $parser->{_link_cursor}='arrow'; 
 $parser->{_text_cursor}='xterm';
 return $parser;
}

#######################################################################
sub next_marker
{
	my ($parser, $key)= @_ ;

	my $cnt = $parser->{_marker_counts}->{$key}++;
	my $marker = $key .'_'. $cnt;
	return $marker;
}



#######################################################################

sub _handle_text 
{
	my $parser = shift(@_);
	my $text = shift( @_ );
	my $tag = $parser->CurrentTag;
	my $font = $parser->CurrentFont;

	$parser->{_widget}->insert('insert', $text, $font);
	$parser->{_widget}->tagAdd
		($tag, 'insert linestart', 'insert lineend');

}

#######################################################################
sub CurrentTag
{
	my $parser = shift(@_);
	$parser->{_current_tag}=shift if(scalar(@_));
	return $parser->{_current_tag};
	
}

#######################################################################
sub CurrentFont
{
	my $parser=shift(@_);
	my $href =  $parser->{_current_font}->[-1];

	my $family = $href->{family};
	my $size   = $href->{size};
	my $weight = $href->{weight};
	my $slant  = $href->{slant};
	my $under  = $href->{underline};

	my $font = $family.$size.$weight.$slant.$under;
	return $font;
}

#######################################################################
sub ColumnTracking
{
	my $parser=shift(@_);
	my ($startend , $element, $attrs)=@_;

	$parser->{_column_indent}=0 unless
		(exists($parser->{_column_indent}));

	if($startend eq 'start')
		{
		if(exists($attrs->{indent}))
			{
			$parser->{_column_indent} += $attrs->{indent};
			}
		push(@{$parser->{_indentable_attributes}}, $attrs);
		}

	elsif( ($startend eq 'end') )
		{
		my $popattrs = pop(@{$parser->{_indentable_attributes}});
		if(exists($popattrs->{indent}))
			{
			$parser->{_column_indent} -= $popattrs->{indent};
			}
		}

	my $col = $parser->{_column_indent};

	$parser->CurrentTag('Column'.$col);

}


#######################################################################
sub FontTracking
{
	my $parser=shift(@_);
	my ($startend , $element, $attrs)=@_;

	unless(exists($parser->{_current_font}))
		{
			$parser->{_current_font}=
			[
				{
				family => 'lucida',	# lucida, courier
				size => 10,		# 10, 12, 18, 24
				weight => 'normal',	# normal, bold
				slant => 'roman', 	# roman, italic
				underline => 'nounder',	# yesunder, nounder 
				}
			];
		}
	

	if($startend eq 'start')
		{
		my $href = $parser->{_current_font}->[-1];

		my %newhash = map { ( $_, $href->{$_} ) } keys(%$href);

		if(0) {}
		elsif($element eq 'C')
			{ 
			$newhash{family}='courier';
			}
		elsif($element eq 'head')
			{ 
			my $hindex = $attrs->{_head_index};
			$newhash{underline}='yesunder';
			if(0) {}
			elsif($hindex eq '1')
				{
				$newhash{size}='18';
				$newhash{weight}='bold';
				}
			elsif($hindex eq '2')
				{
				$newhash{size}='12';
				$newhash{weight}='bold';
				}
			else
				{
				$newhash{weight}='bold';
				}

			}
		elsif($element eq 'I')
			{ 
			$newhash{slant}='italic';
			}
		elsif($element eq 'B')
			{ 
			$newhash{weight}='bold';
			}

		elsif($element eq 'L')
			{ 
			$newhash{underline}='yesunder';
			}

		push(@{$parser->{_current_font}}, \%newhash);
		}
	elsif($startend eq 'end')
		{
		pop(@{$parser->{_current_font}});
		}
	
}


#######################################################################
sub _handle_element_start_and_end
{
	my $parser = shift(@_);

	my $startend = shift(@_);
	my $element= shift(@_);
	$element =~ s{\W}{_}g;
	my $attrs = shift(@_);

	my $mark = $parser->next_marker($startend .'_'.$element);
	$attrs->{_marker}=$mark;

	if(0) {}
	elsif($element =~ s{head(\d+)}{head})
		{
		$attrs->{'_head_index'}=$1;
		}

	my $method = $startend .'_'.$element;

	unless(exists($start_new_line_for_element{$element}))
		{
		die "Error: unknown element type '$element'";
		}

	if($start_new_line_for_element{$element})
		{
		$parser->{_widget}->insert('insert',"\n");
		}

	$parser->{_widget}->markSet($mark, 'insert');
	$parser->{_widget}->markGravity($mark, 'left');

 	$parser->ColumnTracking($startend , $element, $attrs);
 	$parser->FontTracking  ($startend , $element, $attrs);

	if($parser->can($method))
		{
		$parser->$method($attrs);
		}
}


#######################################################################
# these are methods called by the parser, intercept them here
# and send text to widget.
#######################################################################
sub _handle_element_start
{
	my $parser = shift(@_);

	$parser->_handle_element_start_and_end('start', @_);
}

#######################################################################
# these are methods called by the parser, intercept them here
# and send text to widget.
#######################################################################
sub _handle_element_end
{
	my $parser = shift(@_);
	push(@_, {} );
	$parser->_handle_element_start_and_end('end', @_);
}



#######################################################################
# these methods are called automaticlly at the end of 
# the call to _handle_element_start_and_end
#######################################################################

sub get_text_between_start_end_markers
{
	my $parser=shift(@_);

	my $w=$parser->{_widget};

	my $attrs = shift(@_);
	my $end_marker = $attrs->{_marker};
	my $start_marker=$end_marker;
	$start_marker=~s{^end}{start};

	my $start_index = $w->index($start_marker);
	my $end_index = $w->index($end_marker.'-1 char');

	my $text = $w->get($start_index,$end_index);

	return ($start_index,$end_index,$text);
}

my $marker_prefix='MARKER:';

my @index_items;

sub add_to_index
{
	my ($entry,$marker,$depth)=@_;
	my $ref=
		{
		# text for index entry. ex: "Using Array Refs"
		Entry=>$entry,

		# name of marker that points to this entry
		Marker=>$marker,

		# depth of entry in index
		# 1 = top level entry
		# 2 = sub level entry
		# 3 = sub sub level entry, etc.
		Depth=>$depth,
		};

	push(@index_items,$ref);
}

sub end_head
{
	my $parser=shift(@_);
	my $level=$_[0]->{'_head_index'};
	my ($start,$end,$text) = 
		$parser->get_text_between_start_end_markers(@_);
	my $header_marker_name = $marker_prefix.$text;
	$parser->{_widget}->markSet($header_marker_name,$start);

	add_to_index($text,$header_marker_name,$level);
}

sub end_L
{
	my $parser=shift(@_);
	my ($start,$end,$text) = 
		$parser->get_text_between_start_end_markers(@_);

	$text=~s{^\"}{};
	$text=~s{\"$}{};

	my $link_marker_name = $marker_prefix.$text;
	my $tag_name = 'link_'.$start.'_'.$end.'_'.$link_marker_name;

	my $w=$parser->{_widget};
	$w->tagAdd($tag_name, $start, $end);
	$w->tagConfigure($tag_name, -foreground=>'blue');
	$w->tagBind     ($tag_name, '<Button-1>',
		sub{ $w->see($w->index($link_marker_name)) } );

	$w->tagBind($tag_name, '<Enter>',
		sub{ $w->configure(-cursor=> $parser->{_link_cursor}); } );
	$w->tagBind($tag_name, '<Leave>',
		sub{ $w->configure(-cursor=> $parser->{_text_cursor}); } );
}

sub start_item_bullet
{
	my $parser=shift(@_);
	my $attrs=shift(@_);
	my $bullet_string = $attrs->{'~orig_content'};
	$bullet_string .= ' ';
	$parser->{_widget}->insert('insert', $bullet_string );

}



#######################################################################
#######################################################################
package Tk::Peapod;
#######################################################################
#######################################################################

require 5.005_62;
use strict;
use warnings;

our $VERSION = '0.02';

use Data::Dumper;

use Tk qw (Ev);

use  Pod::Simple::Methody;
use base qw(Tk::ROText);

Construct Tk::Widget 'Peapod';

#######################################################################
#######################################################################
sub ClassInit
{
 my ($class,$mw) = @_;
 $class->SUPER::ClassInit($mw);

 $mw->bind($class,'<F1>', 'DumpMarks'); 
 $mw->bind($class,'<F2>', 'DumpTags'); 
 $mw->bind($class,'<F3>', 'DumpCursor'); 

}

#######################################################################
#######################################################################
sub InitObject
{
 my ($w) = @_;
 $w->SUPER::InitObject;

 my $parser = Tk::Peapod::Parser->new();
 $w->{_parser}= $parser;
 $parser->{_widget}=$w;

 $w->configure(-cursor=>$parser->{_text_cursor});

 for(my $i=0; $i<100; $i++)
	{
	 $w->tagConfigure
		(
			'Column'.$i,
 			-lmargin1 => $i*8,
			-lmargin2 => $i*8,
		);
	}

# family    =>  garamond, courier
# size 	    =>  10, 12, 16, 18, 24
# weight    =>  normal, bold
# slant     =>  roman, italic
# underline =>  yesunder, nounder

for my $family qw(lucida courier)
	{
	for my $size qw (6 8 10 12 14 16 18 20 22 24)
		{
		for my $weight qw(normal bold)
			{
			for my $slant qw(roman italic)
				{
				for my $under qw (yesunder nounder)
					{
					my $underval = ($under eq 'yesunder') ? 1 : 0;
					$w->tagConfigure 
						(
						$family.$size.$weight.$slant.$under,
						-font =>
							[
							-family=>$family,
							-size  =>$size,
							-weight=>$weight,
							-slant =>$slant,
							],
						-underline => $underval,
						);
					}
				}
			}
		}
	}

}

#######################################################################
#######################################################################

sub podview
{
	my ($widget, $string)=@_;

	$widget->{_parser}->parse_string_document($string);
}


sub by_line_number
{
	($a->[0]) <=> ($b->[0]);
}

sub DumpMarks
{
	my ($widget)=@_;

	my @marknames = $widget->markNames;

	my @index_mark;
	foreach my $markname (@marknames)
		{
		my $index = $widget->index($markname);
		my ($ln, $col)=split(/[.]/, $index);

		push(@index_mark,[$ln+0,$col+0,$markname]);
		}

	my @sorted = sort by_line_number @index_mark;

	foreach my $arr_ref (@sorted)
		{
		my($ln,$col,$markname)=@$arr_ref;
		my $string = 
			sprintf("% 10u\.% 6u", $ln, $col) . "  $markname\n";
		print $string;
		}

}


sub DumpTags
{
	my ($widget)=@_;

	my @tagname = $widget->tagNames;

	foreach my $tag (@tagname)
		{
		my @indexes = $widget->tagRanges($tag);
		next unless(scalar(@indexes));
		print "\n\n";
		print "tag name '$tag'\n";
		for(my $i=0; $i<scalar(@indexes); $i=$i+2)
			{
			my $start = $indexes[$i];
			my $end   = $indexes[$i+1];
			print "\t $start $end \n";
			}
		}
}


sub DumpCursor
{
	my ($widget)=@_;

	my @tagname = $widget->tagNames('insert');
	print "\n\n";

	foreach my $tag (@tagname)
		{
		my @indexes = $widget->tagRanges($tag);
		next unless(scalar(@indexes));
		#print "\n\n";
		print "tag name '$tag'\n";
		for(my $i=0; $i<scalar(@indexes); $i=$i+2)
			{
			my $start = $indexes[$i];
			my $end   = $indexes[$i+1];
		#	print "\t $start $end \n";
			}
		}
}


1;
__END__


=head1 NAME

Tk::Peapod - POD viewer

=head1 SYNOPSIS

	use Tk;
	use Tk::Peapod;
	
	my $top = MainWindow->new();

	my $peapod = $top->Peapod-> pack;	
	
	{
		local $/;
		my $string = <>;
		$peapod->podview($string);
	}
	
	MainLoop();
	
=head1 ABSTRACT

Tk::Peapod is a POD viewing widget that can be used in Perl/Tk.

The tarball also includes a script called 'peapod' which is a POD viewer.

=head1 DESCRIPTION

Tk::Peapod is a POD viewing widget that can be used in Perl/Tk.

The tarball also includes a script called 'peapod' which is a POD viewer.

=head2 EXPORT

None by default.

=head1 SEE ALSO

peapod : perl script using Tk::Peapod to create a POD viewer. (included)

=head1 AUTHOR

Greg London, http://www.greglondon.com

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Greg London

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut


