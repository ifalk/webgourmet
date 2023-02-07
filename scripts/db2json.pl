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
	   );

my @optkeys = (
	      );

unless (GetOptions (\%opts, @optkeys)) { pod2usage(2); };

print STDERR "Options:\n";
print STDERR Dumper(\%opts);

unless (@ARGV) { pod2usage(2) }; 

my $database = $ARGV[0];

binmode(STDERR, 'encoding(UTF-8)');
#binmode(STDOUT, 'encoding(UTF-8)');

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

use JSON;

use strict;
###############################

my $driver = "SQLite";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { 
	RaiseError => 1,
	sqlite_open_flags => SQLITE_OPEN_READONLY,
	sqlite_unicode => 1, 
	})
   or die $DBI::errstr;

print STDERR "Opened database successfully\n";


# get ingredients and build id -> ingredient hash
# my $ing_stmt = qq(select recipe_id, group_concat(item, ' ') as item from ingredients group by recipe_id;); 
# my $ing_sth = $dbh->prepare( $ing_stmt);
# my $rv = $ing_sth->execute() or die $DBI::errstr;
# if($rv < 0) {
#   print $DBI::errstr;
# }

my $ing_stmt = qq(select * from ingredients where recipe_id in ('246', '1122', '1302');); 
my $ing_sth = $dbh->prepare( $ing_stmt);
my $rv = $ing_sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}


my %recipes_ing;
while (my $ing_list = $ing_sth->fetchrow_hashref()) {
  next if ($ing_list->{deleted});

  my $recipe_id = $ing_list->{recipe_id};

  my $ing_group = 'none';
  if ($ing_list->{inggroup}) {
    $ing_group = $ing_list->{inggroup};
  }
  my $item = $ing_list->{item};

  foreach my $field (qw(amount unit)) {
    $recipes_ing{$recipe_id}->{$ing_group}->{$item}->{$field} = $ing_list->{$field};
  }

  if ($ing_list->{unit} eq 'recipe') {
    $recipes_ing{$recipe_id}->{$ing_group}->{$item}->{refid} = $ing_list->{refid};
  }
  
  $recipes_ing{$recipe_id}->{$ing_group}->{$item}->{optional} = 0;
  if ($ing_list->{optional}) {
    $recipes_ing{$recipe_id}->{$ing_group}->{$item}->{optional} = 1;
  }
  
}

print STDERR Dumper(\%recipes_ing);
exit 1;

#print STDERR Dumper(\%recipes_ing);

print STDERR "Number of ids in ingredient lists: ", scalar(keys %recipes_ing), "\n";

exit 1;

### get recipes

### left join instead of inner join so we get recipe ids even if they don't have categories
my $stmt = qq(select r.id,r.title,r.instructions,r.modifications,r.cuisine,r.rating,r.source,time(r.preptime, 'unixepoch'),time(r.cooktime, 'unixepoch'),r.servings,r.image,r.thumb,r.link,date(r.last_modified,'unixepoch'),r.yields,r.yield_unit,c.category from recipe r left join categories c on r.id=c.recipe_id where r.deleted=0 limit 20);

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

  
  $recipes{$id} = $row;
}

print STDERR "Number of recipes: ", scalar(keys %recipes), "\n";

my @ids_no_cat = grep {not defined $recipes{$_}->{category} } keys %recipes;

if (@ids_no_cat) {
  print STDERR "There are $#ids_no_cat recipes without a category: \n";
  print STDERR join (', ', sort {$a <=> $b} @ids_no_cat), "\n";
}

### convert to json
my @recipes_json;

foreach my $id (sort {$a <=> $b} keys %recipes) {

  my $entry = {
    'id' => $id,
      'title' => $recipes{$id}->{'title'} ? $recipes{$id}->{'title'} : '',
      'ingredients' => $recipes{$id}->{'ingredients'} ? $recipes{$id}->{'ingredients'} : '',
      'instructions' => $recipes{$id}->{'instructions'} ? $recipes{$id}->{'instructions'} : '',
      'modifications' => $recipes{$id}->{'modifications'} ? $recipes{$id}->{'modifications'} : '',
    'category' => $recipes{$id}->{'category'} ? $recipes{$id}->{'category'} : '',
    'yields' => $recipes{$id}->{'yields'} ? $recipes{$id}->{'yields'} : '0',
    'yieldunits' => $recipes{$id}->{'yield_unit'} ? $recipes{$id}->{'yield_unit'} : '',
    'rating' => $recipes{$id}->{'rating'} ? $recipes{$id}->{'rating'} : '',
  };

  foreach my $key (qw(title instructions modifications ingredients)) {
    if ($recipes{$id}->{$key}) {
      $recipes{$id}->{$key} =~ s{"}{}xmsg;
      $recipes{$id}->{$key} =~ s{\r}{}g;
      $recipes{$id}->{$key} =~ s{\t}{ }xmsg;
    }
  }

  my $searchfield = join(',', map { $recipes{$id}->{$_} or '' } (qw(title ingredients instructions modifications source category)));
  $entry->{'searchfield'} = $searchfield;


  push (@recipes_json, $entry);

}

#print Dumper(\@recipes_json);
#print encode_json \@recipes_json;

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
