#### How do units look in db?

use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my $sth = Local::Modulino::DB2JSON->fetch_units($dbh);

my %units;

while (my ($unit) = $sth->fetchrow()) {
  if ($unit) {
    $units{$unit}++;
  } else {
    $unit{'undef'}++;
  }
}

print STDERR "Number of distinct units: ", scalar(keys %units), "\n";

$sth = Local::Modulino::DB2JSON->fetch_recipes_wo_unit($dbh);

my @recipes_wo_unit;

while (my ($unit) = $sth->fetchrow()) {
  push(@recipes_wo_unit, $unit);
};

print STDERR "Number of recipes with ingredient wo unit: ", scalar(keys @recipes_wo_unit), "\n";

my $recipe_wo_unit = $recipes_wo_unit[0];

### How does a row in the ingredients table look (wo and w unit)?

$sth = Local::Modulino::DB2JSON->fetch_some_ingredients($dbh, [$recipe_wo_unit]);
my $select_fields = qq(recipe_id,refid,unit,amount,rangeamount,item,ingkey,optional,inggroup);

my $stmt = qq(select $select_fields from ingredients where recipe_id in ($recipe_wo_unit) and deleted=0;); 
my $sth = $dbh->prepare( $stmt);
my $rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

while (my $ing = $sth->fetchrow_hashref()) {

  print STDERR "Recipe id $ing->{recipe_id}, item: $ing->{item}, unit: ";
  
  
  if ($ing->{'unit'}) {
    print STDERR "$ing->{unit}\n";
  } else {
    print STDERR "not defined\n";
  }
}

$dbh->disconnect;
