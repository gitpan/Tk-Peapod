
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

	$parser->{_pod_widget}->insert('insert', $text, $font);
	$parser->{_pod_widget}->tagAdd
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
#######################################################################

#	my $font = $family.$size.$weight.$slant.$under;

my @head_font =
	(
	'BAD INDEX INTO @head_font ARRAY',
	join ('', qw ( lucida 1 bold roman nounder )), # head1 => largest size
	join ('', qw ( lucida 2 bold roman nounder )), # head2 => middle size
	join ('', qw ( lucida 3 bold roman nounder )), # head3 => small size
	join ('', qw ( lucida 4 bold roman nounder )), # normal text
	);

#######################################################################
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
				size => 4,		# 1,2,3,4
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
			$newhash{size}=$hindex;
			$newhash{weight}='bold';
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

	my $w=$parser->{_pod_widget};

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
		$w->insert('insert',"\n");
		}

	$w->markSet($mark, 'insert');
	$w->markGravity($mark, 'left');

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

	my $w=$parser->{_pod_widget};

	my $attrs = shift(@_);
	my $end_marker = $attrs->{_marker};
	my $start_marker=$end_marker;
	$start_marker=~s{^end}{start};

	my $start_index = $w->index($start_marker);
	# my $end_index = $w->index($end_marker.'-1 char');
	my $end_index = $w->index($end_marker);

	my $text = $w->get($start_index,$end_index);

	return ($start_index,$end_index,$text);
}

#######################################################################
#######################################################################
#######################################################################
#######################################################################

my $marker_prefix='MARKER:';

my @index_items;

#######################################################################
sub label_most_recent_section
#######################################################################
{
	my ($href)=@_;

	my $temp_ref = \@index_items;
	my @section_number;

	while(1)
		{
		push(@section_number, scalar(@$temp_ref));
		$temp_ref = $temp_ref->[-1]->{Subparagraph};
		last unless(scalar( @$temp_ref ));
		}

	my $section_string = join('.', @section_number) . ': ';

	$href -> {Section}=$section_string;

	return $section_string;
}

#######################################################################
sub add_to_table_of_contents
#######################################################################
{
	my ($parser, $entry,$marker,$depth)=@_;
	my $href=
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

		Subparagraph => [],
		};

	
	###############################################################
	# first, figure out where to put the $href entry...
	###############################################################

	my $arr_ref = \@index_items;

	for(my $cnt=1; $cnt<$depth; $cnt++)
		{
		unless(scalar(@$arr_ref))
			{
			my $href = 
				{ 
				Entry=>'WARN: skipped this paragraph',
				Subparagraph=>[],
				};

			push(@$arr_ref, $href);

			label_most_recent_section($href);
			}

		$arr_ref = $arr_ref->[-1]->{Subparagraph};
		}

	push(@$arr_ref,$href);


	###############################################################
	# now go back and label the last href with the proper section number
	###############################################################
	my $section_string = label_most_recent_section($href);
	my $w=$parser->{_pod_widget};
	my $index = $w->index($marker);
	$w->insert($index, $section_string, $head_font[$depth] );

	return $section_string;
}


#######################################################################
sub end_head
#######################################################################
{
	my $parser=shift(@_);
	my $level=$_[0]->{'_head_index'};
	my ($start,$end,$text) = 
		$parser->get_text_between_start_end_markers(@_);
	chop($text);
	my $header_marker_name = $marker_prefix.$text;

	$parser->{_pod_widget}->markSet($header_marker_name,$start);

	my $index = add_to_table_of_contents($parser, $text,$header_marker_name,$level);

	my $toc=$parser->{_toc_widget};
	my $pod=$parser->{_pod_widget};

	my $toc_indent = '  'x$level;
	my $toc_string = $toc_indent.$index.$text;
	chomp($toc_string);

	my $toc_tag = $header_marker_name;

	$toc->insert('insert', $toc_string);
	$toc->tagAdd($toc_tag, 'insert linestart', 'insert lineend');
	$toc->tagBind($toc_tag, '<Button-1>',
		sub{ $pod->see($pod->index($header_marker_name)); } );

	$toc->insert('insert',"\n");

}


my $most_recent_link;

sub start_L
{
	my $parser=shift(@_);
	my $attrs = shift(@_);
	my %attributes = %$attrs;
	my $new_attrs = \%attributes;
	$most_recent_link = $new_attrs;
}

#######################################################################
sub end_L
#######################################################################
# hyperlinks can have 1 of 3 formats
# L<name> where name is another module, L<Net::Ping>
# L<name/sec> or L<name/"sec"> where sec refers to 
#		a section in the named module
# 		L<perlsyn/"For Loops">
# L</sec> a link to a section in this current manual
#######################################################################

{
	my $parser=shift(@_);
	my $attrs=shift(@_);

	my $link_type = 
		  (exists($most_recent_link->{to}))      ? 'to'
		: (exists($most_recent_link->{section})) ? 'section'
		: 'ERROR';

	die "Unknown link type ".(Dumper $most_recent_link) if($link_type eq 'ERROR');

	my ($start,$end,$text) = 
		$parser->get_text_between_start_end_markers($attrs);

	$text=~s{^\"}{};
	$text=~s{\"$}{};

	my $link_marker_name = $marker_prefix.$text;
	my $tag_name = 'link_'.$start.'_'.$end.'_'.$link_marker_name;

	my $w=$parser->{_pod_widget};
	$w->tagAdd($tag_name, $start, $end);
	$w->tagConfigure($tag_name, -foreground=>'blue');

	my $sub_lut = 
		{
		section => sub{eval{$w->see($w->index($link_marker_name));};},
		to => sub{eval{system("$0 $text");};},
		};

	$w->tagBind     ($tag_name, '<Button-1>', $sub_lut->{$link_type});

	$w->tagBind($tag_name, '<Enter>',
		sub{ $w->configure(-cursor=> $parser->{_link_cursor}); } );
	$w->tagBind($tag_name, '<Leave>',
		sub{ $w->configure(-cursor=> $parser->{_text_cursor}); } );
}

#######################################################################
sub start_item_bullet
#######################################################################
{
	my $parser=shift(@_);
	my $attrs=shift(@_);
	my $bullet_string = $attrs->{'~orig_content'};
	$bullet_string .= ' ';
	$parser->{_pod_widget}->insert('insert', $bullet_string );

}



#######################################################################
#######################################################################
package Tk::Peapod;
#######################################################################
#######################################################################

require 5.005_62;
use strict;
use warnings;

our $VERSION = '0.07';

use Data::Dumper;

use Tk qw (Ev);
use Tk::ROText;
use Tk::Adjuster;

use  Pod::Simple::Methody;

use base qw(Tk::Frame);

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


sub set_font_tags
{
	# pass in a list of font sizes to correspond to the 4 text sizes
	# by default, use these values:	
	my ($self, @font_sizes)=@_; # 

	my $pod = $self->Subwidget('pod');

	unless(scalar(@font_sizes))
		{
		@font_sizes= qw( 18 16 12 10 );
		}

	unshift(@font_sizes, 'EMTPY');

 	for(my $i=0; $i<100; $i++)
		{
		 $pod->tagConfigure
			(
				'Column'.$i,
	 			-lmargin1 => $i*8,
				-lmargin2 => $i*8,
			);
		}

	# family    =>  garamond, courier
	# size 	    =>  10, 12, 16, 18
	# weight    =>  normal, bold
	# slant     =>  roman, italic
	# underline =>  yesunder, nounder

for my $family qw(lucida courier)
	{
	for my $relative_size qw ( 1 2 3 4 )
		{
		my $font_size = $font_sizes[$relative_size];

		for my $weight qw(normal bold)
			{
			for my $slant qw(roman italic)
				{
				for my $under qw (yesunder nounder)
					{
					my $underval = ($under eq 'yesunder') ? 1 : 0;
					$pod->tagConfigure 
						(
						$family.$relative_size.$weight.$slant.$under,
						-font =>
							[
							-family=>$family,
							-size  =>$font_size,
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

sub Populate
{
	my($self, $args)=@_;

	$self->SUPER::Populate($args);

	my $toc = $self->ROText( -width => 20 )
		->pack(-side=> 'left',-fill=>'both');
	
	$toc->configure(-wrap=>'none');

	my $adj = $self->Adjuster(-widget=>$toc, -side=>'left')
		->pack(-side=>'left',-fill=>'y');

	my $pod = $self->ROText(-width=>80)
		->pack(-side=>'right',-fill=>'both',-expand=>1);

	$self->Advertise  (    'toc'=> $toc );
	$self->Advertise  (    'pod'=> $pod );
	$self->ConfigSpecs('DEFAULT'=>[$pod]);
	$self->Delegates  ('DEFAULT'=> $pod );

	$self->Delegates  ('podview'=>$self);

	$self->set_font_tags;

	my $parser = Tk::Peapod::Parser->new();
	$self->{_parser}= $parser;
	$parser->{_widget}=$self;
	$parser->{_pod_widget}=$pod;
	$parser->{_toc_widget}=$toc;
	

	$pod->configure(-cursor=>$parser->{_text_cursor});

	$pod->bind('<F1>', sub{$self->DumpMarks}); 
	$pod->bind('<F2>', sub{$self->DumpTags}); 
	$pod->bind('<F3>', sub{$self->DumpCursor}); 

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
	my ($bigwidget)=@_;
	my $widget = $bigwidget->Subwidget('pod');

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
	my ($bigwidget)=@_;
	my $widget = $bigwidget->Subwidget('pod');

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
	my ($bigwidget)=@_;
	my $widget = $bigwidget->Subwidget('pod');

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









