use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

### check how to render time values from database

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my %test_recipe_ids = (
  # recipe ids, the time strings we expect 0 and test names (what we test) 1
  '1833' => [ '',
	      'db preptime 00:00'],
  '1579' => [ '1 h 50 min',
	      'db preptime > 1 hour, with minutes'],
  '1566' => [ '2 h',
	      'db preptime only hours, no minutes'],
  '1601' => [ '15 min',
	      'db preptime only minutes, no hours, >10'],
  '1609' => [ '8 min',
	      'db preptime only minutes, no hours, <10'],
  '48' => [ '',
	    'db preptime null, early recipe'],
  '1711' => [ '',
	      'db preptime null, later recipe']
  );

my $time_values = [keys %test_recipe_ids];
my $time_values_string = join(',', @{ $time_values });

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);
my $stmt = qq(select id, title, strftime('%H:%M', preptime, 'unixepoch') from recipe where id in ($time_values_string););
my $sth = $dbh->prepare($stmt);

$rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

while (my ($id, $title, $db_preptime) = $sth->fetchrow()) {

  my $time_string = Local::Modulino::DB2JSON->stringify_db_time($db_preptime);


  is ($time_string, $test_recipe_ids{$id}->[0], "id $id, preptime $test_recipe_ids{$id}->[0],  $test_recipe_ids{$id}->[1]");
  
  # print STDERR "$id, $title: $yield_string\n";
  
}

$dbh->disconnect();



# my $stmt = qq(select distinct strftime('%H:%M', preptime, 'unixepoch') from recipe;);
# my $sth = $dbh->prepare($stmt);

# my $rv = $sth->execute() or die $DBI::errstr;
# if($rv < 0) {
#   print $DBI::errstr;
# }

# print STDERR "Distinct preptimes:\n";
# while (my ($db_preptime) = $sth->fetchrow()) {
#   print STDERR Local::Modulino::DB2JSON->stringify_db_time($db_preptime), "\n";
# }

# $stmt = qq(select distinct strftime('%H:%M', preptime, 'unixepoch') from recipe;);
# $sth = $dbh->prepare($stmt);

# $rv = $sth->execute() or die $DBI::errstr;
# if($rv < 0) {
#   print $DBI::errstr;
# }

# print STDERR "Distinct cooktimes:\n";
# while (my ($db_cooktime) = $sth->fetchrow()) {
#   print STDERR Local::Modulino::DB2JSON->stringify_db_time($db_cooktime), "\n";
# }

# $dbh->disconnect();
