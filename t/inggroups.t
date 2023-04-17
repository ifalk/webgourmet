#### How do inggroups look in db?

use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

my $sth = Local::Modulino::GourmetExport->fetch_inggroups($dbh);

my %inggroups;

while (my ($inggroup) = $sth->fetchrow()) {
  if ($inggroup) {
    $inggroups{$inggroup}++;
  } else {
    $inggroup{'undef'}++;
  }
}

print STDERR "Number of distinct inggroups: ", scalar(keys %inggroups), "\n";


$sth = Local::Modulino::GourmetExport->fetch_recipes_wo_inggroup($dbh);

my @recipes_wo_inggroup;

while (my ($inggroup) = $sth->fetchrow()) {
  push(@recipes_wo_inggroup, $inggroup);
};

print STDERR "Number of recipes wo inggroup: ", scalar(keys @recipes_wo_inggroup), "\n";

### How does a row in the ingredients table look (wo and w inggroup)?

$sth = Local::Modulino::GourmetExport->fetch_some_ingredients($dbh, [1888, 1889]);

while (my $ing = $sth->fetchrow_hashref()) {

  print STDERR Dumper($ing);

  ### Unset fields are undef:
  # $VAR1 = {
  #           'recipe_id' => 1888,
  #           'item' => 'carrots, peeled and cut into 2cm chunks',
  #           'position' => 0,
  #           'rangeamount' => undef,
  #           'amount' => '2',
  #           'unit' => undef,
  #           'deleted' => 0,
  #           'shopoptional' => undef,
  #           'refid' => undef,
  #           'inggroup' => undef,
  #           'optional' => 0,
  #           'id' => 12404,
  #           'ingkey' => 'carrots, peeled and cut into 2cm chunks'
  #         };

  if ($ing->{'inggroup'}) {
    print STDERR "inggroup defined\n";
  } else {
    print STDERR "inggroup not defined\n";
  }
}

$dbh->disconnect;
