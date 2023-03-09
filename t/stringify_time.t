use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

### check how to render time values from database

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my $stmt = qq(select distinct strftime('%M', preptime, 'unixepoch') from recipe;);
my $sth = $dbh->prepare($stmt);

my $rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

print STDERR "Distinct preptimes:\n";
while (my ($db_preptime) = $sth->fetchrow()) {
  print STDERR Local::Modulino::DB2JSON->stringify_db_time($db_preptime), "\n";
}

$stmt = qq(select distinct strftime('%M', preptime, 'unixepoch') from recipe;);
$sth = $dbh->prepare($stmt);

$rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

print STDERR "Distinct cooktimes:\n";
while (my ($db_cooktime) = $sth->fetchrow()) {
  print STDERR Local::Modulino::DB2JSON->stringify_db_time($db_cooktime), "\n";
}

$dbh->disconnect();
