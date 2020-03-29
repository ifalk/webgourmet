#!/usr/bin/perl
# -*- mode: perl; buffer-file-coding-system: utf-8 -*-
# db2json.pl                   falk@gurumusch
#                    28 Mär 2020

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

perl db2json.pl 

=head1 USAGE

   perl db2json.pl recipes.db

=head1 DESCRIPTION

Reads gourmet recipe db (sqlite) and produces a json data structure, written to STDOUT

=head1 REQUIRED ARGUMENTS

The recipe db

=head1 OPTIONS

=cut


my %opts = (
	    'links' => '',
	   );

my @optkeys = (
	       'links=s',
	      );

unless (GetOptions (\%opts, @optkeys)) { pod2usage(2); };

print STDERR "Options:\n";
print STDERR Dumper(\%opts);

use List::MoreUtils qw(all);

my @required = ('links');

unless (all { $opts{$_} } @required) { pod2usage(2) };
unless (@ARGV) { pod2usage(2) }; 

my $database = $ARGV[0];
my %ids2links = %{ require "$opts{links}" };

#binmode(STDERR, 'encoding(UTF-8)');
#binmode(STDOUT, 'encoding(UTF-8)');

use DBI;
use DBD::SQLite::Constants qw/:file_open/;


my $driver = "SQLite";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { 
	RaiseError => 1,
	sqlite_open_flags => SQLITE_OPEN_READONLY, 
	})
   or die $DBI::errstr;

print STDERR "Opened database successfully\n";


# get ingredients and build id -> ingredient hash
my $ing_stmt = qq(select recipe_id, group_concat(item, ' ') as item from ingredients group by recipe_id;); 
my $ing_sth = $dbh->prepare( $ing_stmt);
my $rv = $ing_sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}


my %recipes_ing;
while (my $ing_list = $ing_sth->fetchrow_hashref()) {
  if ($ing_list->{'item'}) {
    $recipes_ing{$ing_list->{'recipe_id'}} = $ing_list->{'item'};
  }
}

print STDERR "Number of ids in ingredient lists: ", scalar(keys %recipes_ing), "\n";

my $stmt = qq(select r.id,r.title,r.yields,r.yield_unit,r.instructions,r.modifications,r.source,r.rating,c.category,r.deleted from recipe r inner join categories c on r.id=c.recipe_id where r.deleted=0);
my $sth = $dbh->prepare( $stmt );

$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print $DBI::errstr;
}

my $count = 0;
my %recipes;

while (my $row = $sth->fetchrow_hashref()) {
  my $id = $row->{'id'};


  my $instructions = $row->{'instructions'};
  if ($instructions) {
    $row->{'instructions'} = join(';', split(/\n+/, $instructions));
  }

  if (exists $recipes_ing{$id}) {
    $row->{'ingredients'} = $recipes_ing{$id};
  } else {
    print STDERR "recipe $id ($row->{title}) has no ingredients\n";
  };

  if ($ids2links{$id}) {
    $row->{'linkrecipe'} = $ids2links{$id};
  } else {
    print STDERR "recipe $id ($row->{title}) has no link\n";
  }
  
  foreach my $key (qw(title instructions ingredients)) {
    if ($row->{$key}) {
      $row->{$key} =~ s{"}{}xmsg;
      $row->{$key} =~ s{\r}{}g;
      $row->{$key} =~ s{\t}{ }xmsg;
    }
  }
  
  $recipes{$id} = $row;
}

print STDERR "Number of recipes: ", scalar(keys %recipes), "\n";

my @ids_no_cat = grep {not defined $recipes{$_}->{category} } keys %recipes;

if (@ids_no_cat) {
  print STDERR "There are $#ids_no_cat recipes without a category: \n";
  print STDERR join (', ', sort {$a <=> $b} @ids_no_cat), "\n";
}

print Dumper(\%recipes);

#$sth->finish();
$dbh->disconnect();


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
