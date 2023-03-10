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

  # if ($servings) {
  #   $yield_string = "$servings servings";
  #   print STDERR "$id, $title: $yield_string\n";
  #   next;
  # }

  # if ($yields) {
  #   $yield_string = join(' ', $yields, $yield_unit); 
  #   print STDERR "$id, $title: $yield_string\n";
  #   next;
  # }

  print STDERR "$id, $title: $yield_string\n";
  
}

$dbh->disconnect();

