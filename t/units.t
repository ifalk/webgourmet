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

#### for some reason this does not really work ?????
# $sth = Local::Modulino::DB2JSON->fetch_recipes_wo_unit($dbh);

# my @recipes_wo_unit;

# while (my ($unit) = $sth->fetchrow()) {
#   push(@recipes_wo_unit, $unit);
# };

# print STDERR "Number of recipes wo unit: ", scalar(keys @recipes_wo_unit), "\n";

# my $recipe_wo_unit = $recipes_wo_unit[0];

# ### How does a row in the ingredients table look (wo and w unit)?

# $sth = Local::Modulino::DB2JSON->fetch_some_ingredients($dbh, [$recipe_wo_unit]);

# while (my $ing = $sth->fetchrow_hashref()) {

#   print STDERR Dumper($ing);


#   if ($ing->{'unit'}) {
#     print STDERR "unit defined\n";
#   } else {
#     print STDERR "unit not defined\n";
#   }
# }

$dbh->disconnect;
