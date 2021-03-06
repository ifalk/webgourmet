#!/usr/bin/perl
# -*- mode: perl; buffer-file-coding-system: utf-8 -*-
# get_id2html_links.pl                   falk@gurumusch
#                    27 Mär 2020

use warnings;
use strict;
use English;

use Data::Dumper;
use Carp;
use Carp::Assert;

use Pod::Usage;
use Getopt::Long;

use utf8;

=head1 NAME

get_id2html_links.pl

=head1 USAGE

   perl get_id2html_links.pl index.htm

=head1 DESCRIPTION

Extracts from the gourmet html export generated index.htm(l) file a
hash mapping db ids to recipe html files (containing the actual
recipes).

The hash is written to STDOUT via C<Data::Dumper>.

The format is as follows:

                     db-id html file generated by gourmet html export
                     |     |
                     v     v
    my $id2link = { 
                    125 => 'Potato and Leek Frittata Recipe125.htm',
                    ....
                    }

=head1 REQUIRED ARGUMENTS

File containing html table with recipes generated by gourmet html
export.  

A table data or I<td> element in the table is expected to contain a reference or
link to an C<html> file containing the recipe description. It should look somewhat like this:

   <td><a href="Potato and Leek Frittata Recipe1.htm">Potato and Leek Frittata Recipe</a></td>


=head1 OPTIONS

=cut

# Commented because no options at the moment

# my %opts = (
# 	    'an_option' => 'default value',
# 	   );

# my @optkeys = (
# 	       'an_option:s',
# 	      );

# unless (GetOptions (\%opts, @optkeys)) { pod2usage(2); };

# print STDERR "Options:\n";
# print STDERR Dumper(\%opts);

# use List::MoreUtils qw(all);

# my @required = (;)

# unless (all { $opts{$_} } @required) { pod2usage(2) };
unless (@ARGV) { pod2usage(2) }; 


binmode(STDERR, 'encoding(UTF-8)');
binmode(STDOUT, 'encoding(UTF-8)');

my $id2link;

use HTML::Parser ();

open my $fh, '<:encoding(utf-8)', $ARGV[0] or croak "Couldn't open $ARGV[0] for input:$!\n";

my $p = HTML::Parser->new(api_version => 3,
     start_h => [\&a_start_handler, "self,tagname,attr"],
     report_tags => [qw(a img)],
    );
$p->parse_file($fh);
 
sub a_start_handler
{
    my($self, $tag, $attr) = @_;
    return unless $tag eq "a";
    return unless exists $attr->{href};
    # print "A $attr->{href}\n";
    my $link = $attr->{href};
    my $id = 'no_id';
    if ($link =~ m{(\d+)\.htm}) {
      $id = $1;
      $id2link->{$id} = $link;
    };
	
    $self->handler(text  => [], '@{dtext}' );
    $self->handler(start => \&img_handler);
    $self->handler(end   => \&a_end_handler, "self,tagname");
}
 
sub img_handler
{
    my($self, $tag, $attr) = @_;
    return unless $tag eq "img";
    push(@{$self->handler("text")}, $attr->{alt} || "[IMG]");
}
 
sub a_end_handler
{
    my($self, $tag) = @_;
    my $text = join("", @{$self->handler("text")});
    # $text =~ s/^\s+//;
    # $text =~ s/\s+$//;
    # $text =~ s/\s+/ /g;
    # print "T $text\n";
 
    $self->handler("text", undef);
    $self->handler("start", \&a_start_handler);
    $self->handler("end", undef);
}

print Dumper($id2link);

1;


__END__

=head1 EXIT STATUS

=head1 CONFIGURATION

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

created by template.el.

It looks like the author of this script was negligent
enough to leave the stub unedited.


=head1 AUTHOR

Ingrid Falk, E<lt>E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020 by Ingrid Falk

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
