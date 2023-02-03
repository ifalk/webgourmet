#!/usr/bin/perl
# -*- mode: perl; buffer-file-coding-system: utf-8 -*-
# 18/01/2023

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
=head1 NAME

db2html.pl

=head1 USAGE

   perl db2html.pl db_file

=head1 DESCRIPTION

Check how to extract relevant information from db and produce html file for each recipe

=head1 REQUIRED ARGUMENTS

File containing recipe database


=head1 OPTIONS

=cut

my %opts = (
	   );

my @optkeys = (
	      );

unless (GetOptions (\%opts, @optkeys)) { pod2usage(2); };

print STDERR "Options:\n";
print STDERR Dumper(\%opts);

use List::MoreUtils qw(all);

my @required = ();

unless (all { $opts{$_} } @required) { pod2usage(2) };
unless (@ARGV) { pod2usage(2) }; 

my $database = $ARGV[0];

#binmode(STDERR, 'encoding(UTF-8)');

use DBI;
use strict;

my $driver   = "SQLite"; 
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) 
   or die $DBI::errstr;

print STDERR "Opened database successfully\n";

### get recipes

### left join instead of inner join so we get recipe ids even if they don't have categories
my $stmt = qq(select r.id,r.title,r.instructions,r.modifications,r.cuisine,r.rating,r.source,time(r.preptime, 'unixepoch'),time(r.cooktime, 'unixepoch'),r.servings,r.image,r.thumb,r.link,date(r.last_modified,'unixepoch'),r.yields,r.yield_unit,c.category from recipe r left join categories c on r.id=c.recipe_id where r.deleted=0);

my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print STDERR $DBI::errstr;
}

my %recipes; # keys = ids

my @recipe_keys = qw(id title instructions modifications cuisine rating source preptime cooktime servings image thumb link last_modified yields yield_unit category);

my %recipe_fields;
@recipe_fields{@recipe_keys} = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);

my @warn_fields = qw(title category);

my %dup_counts;

my $image_data;
my $thumb_data;
while (my $row = $sth->fetchrow_arrayref()) {

  if ($row->[$recipe_fields{'image'}]) {
    binmode(STDERR);

#    print STDERR Dumper($row);

    $image_data = $row->[$recipe_fields{'image'}];
#    print STDERR $image_data, "\n";

    if ($row->[$recipe_fields{'thumb'}]) {
      $thumb_data = $row->[$recipe_fields{'thumb'}];
    }
    
    last;
    
    my $id = $row->[0];

    if ($recipes{$id}) {
      $dup_counts{$id}++;
    }

    foreach my $field (@recipe_keys[1 .. 16]) {
      $recipes{$id}->{$field} = '';
      $recipes{$id}->{$field} = $row->[$recipe_fields{$field}]
    }

  }

}


foreach my $id (keys %recipes) {
  foreach my $field (@warn_fields) {
    unless ($recipes{$id}->{$field}) {
      warn "$field empty for id $id";
    }
  }
}

### try printing images

open my $fh, '>', 'img.png' or die $!;
binmode $fh;
print $fh $image_data;
close $fh;

if ($thumb_data) {
  open my $fh, '>', 'thmb.png' or die $!;
  binmode $fh;
  print $fh $thumb_data;
  close $fh;
}


# print STDERR Dumper(\%recipes);

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

