#!/usr/bin/perl
# -*- mode: perl; buffer-file-coding-system: utf-8 -*-
# exportjson.pl                   falk@gurumusch
#                    22 Sep 2020

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

exportjson.pl

=head1 USAGE

   perl exportjson.pl --ids2links=id_2html_links.pl db_file

=head1 DESCRIPTION



=head1 REQUIRED ARGUMENTS

File containing recipe database


=head1 OPTIONS

=cut


my %opts = (
	    'ids2links' => '',
	   );

my @optkeys = (
	       'ids2links:s',
	      );

unless (GetOptions (\%opts, @optkeys)) { pod2usage(2); };

print STDERR "Options:\n";
print STDERR Dumper(\%opts);

use List::MoreUtils qw(all);

my @required = ('ids2links');

unless (all { $opts{$_} } @required) { pod2usage(2) };
unless (@ARGV) { pod2usage(2) }; 

my $database = $ARGV[0];

my $file = $opts{ids2links};
my %ids2links = ();

if (my $return = do $file) {
  %ids2links = %{ $return };
} else {
  warn "couldn't parse $file: $@" if $@;
  warn "couldn't do $file: $!"    unless defined $return;
  warn "couldn't run $file"       unless $return;
}


binmode(STDERR, 'encoding(UTF-8)');
#binmode(STDOUT, 'encoding(UTF-8)');

use DBI;
use strict;

my $driver   = "SQLite"; 
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) 
   or die $DBI::errstr;

print STDERR "Opened database successfully\n";

### get all recipes

### left join instead of inner join so we get recipe ids even if they don't have categories
my $stmt = qq(select r.id,r.title,r.instructions,r.modifications,r.cuisine,r.source,r.link,datetime(r.last_modified,'unixepoch'),c.category from recipe r left join categories c on r.id=c.recipe_id where r.deleted=0);

my $sth = $dbh->prepare( $stmt );
my $rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print STDERR $DBI::errstr;
}

my %recipes; # keys = ids

my @recipe_keys = qw(id title instructions modifications cuisine source link last_modified category);

my %recipe_fields;
@recipe_fields{@recipe_keys} = (0, 1, 2, 3, 4, 5, 6, 7, 8);

my @warn_fields = qw(title category);

while (my $row = $sth->fetchrow_arrayref()) {

  my $id = $row->[0];
  
  foreach my $field (@recipe_keys[1 .. 8]) {
    $recipes{$id}->{$field} = '';
    $recipes{$id}->{$field} = $row->[$recipe_fields{$field}]
  }
}

foreach my $id (keys %recipes) {
  foreach my $field (@warn_fields) {
    unless ($recipes{$id}->{$field}) {
      warn "$field empty for id $id";
    }
  }
}



### test if there is an html file for each (recipe) id


print STDERR "Number of recipes: ", scalar(keys %recipes), "\n";
print STDERR "Number of html files: ", scalar(keys %ids2links), "\n";

foreach my $id (keys %recipes) {
  unless ($ids2links{$id}) {
    warn "No html file for recipe id $id ($recipes{$id}->{title})";
  }
}

foreach my $id (keys %ids2links) {
  unless ($recipes{$id}) {
    warn "No db entry for html file with id $id ($ids2links{$id})";
  }
}

### get ingredients


$stmt = qq(select id, recipe_id, item from ingredients i where i.deleted=0;);

$sth = $dbh->prepare( $stmt );
$rv = $sth->execute() or die $DBI::errstr;

if($rv < 0) {
   print STDERR $DBI::errstr;
}

while (my $row = $sth->fetchrow_hashref()) {
  croak unless $row->{recipe_id};
  my $id = $row->{recipe_id};
  if ($row->{'item'}) {
    if (exists $recipes{$id}) {
      $recipes{$id}->{'ingredients'}->{$row->{item}}++;
    }
  }
}


print STDERR "Operation done successfully\n";
$dbh->disconnect();


### build json structure: array of hashes: [ { id => .., title => "<a href='...'>title</a>", category => ..., searchfield => ... }, ... ]

my $recipes_json = [];

foreach my $id (keys %recipes) {
  my $jentry;
  $jentry->{'id'} = $id;
  my $link;
  if ($ids2links{$id}) {
    $link = "<a href='$ids2links{$id}'>$recipes{$id}->{title}</a>";
  } else {
    warn "No link for id $id";
    print STDERR Dumper($recipes{$id});
    print STDERR "\n";
  }
  $jentry->{'title'} = $link;
  $jentry->{'category'} = $recipes{$id}->{'category'};
  my $ingredients = join(' ', keys %{ $recipes{$id}->{'ingredients'} });
  $jentry->{'searchfield'} = join(' ', $id, $ingredients, @{ $recipes{$id} }{qw(title cuisine source link category modifications instructions)});

  push(@{ $recipes_json }, $jentry)
}

use JSON;
my $json_text = to_json( $recipes_json, {utf8=>0, pretty=>0} );
print $json_text;
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
