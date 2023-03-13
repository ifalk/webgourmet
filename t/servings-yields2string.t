use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

### check how to render time values from database

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

### test yields/servings
# - 2/3: 1210
# - 0.75: 1211
# - 2.75: 1222
# - 400 : 1542
# yield unit null, yields not null: 1168
# servings and yields null (yield unit not null): 1366
# servings not null: 1143

my %test_recipe_ids = (
  # recipe ids, the yield strings we expect 0 and test names 1
  '1210' => [ '2/3 cup',
	      '2/3'],
  '1211' => [ '3/4 cup',
	      '0.75'],
  '1222' => [ '2 3/4 cups',
	      '2.75'],
  '1542' => [ '400 ml',
	      '400.0'],
  '1168' => [ '4',
	      'yield unit null, yields not null'],
  '1366' => [ '',
	      'servings and yields null (yield unit not null)'],
  '1143' => [ '4 servings',
	      'servings not null']
  );


my $yield_values = [1210, 1211, 1222, 1542, 1168, 1366, 1143];
my $yield_values_string = join(',', @{ $yield_values });

my $stmt = qq(select id, title, servings, yields, yield_unit from recipe where id in ($yield_values_string););
my $sth = $dbh->prepare($stmt);

$rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

while (my ($id, $title, $db_servings, $db_yields, $yield_unit) = $sth->fetchrow()) {

  my $yield_string = Local::Modulino::DB2JSON->stringify_yields($db_servings, $db_yields, $yield_unit);


  is ($yield_string, $test_recipe_ids{$id}->[0], "id $id: $test_recipe_ids{$id}->[1]");
  
  # print STDERR "$id, $title: $yield_string\n";
  
}

$dbh->disconnect();

