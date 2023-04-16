use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

#### build html files for all recipes, for which data was previously exported to hashes

my $recipe_hash = {};
my $ingredient_hash = {};


#### extract max recipe id (shows which recipes are older/newer)
use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my $max_rid = Local::Modulino::DB2JSON->get_max_id($dbh);
print STDERR "Max recipe id: $max_rid\n";

#### No longer need to access db, disconnect
$dbh->disconnect();

#### picture directory in html file: has to be relative to where the html file is
my $html_dir = 'html_export';
my $rel_picdir = 'pics';

########################################
### create html documents for all recipes in db
########################################

Local::Modulino::DB2JSON->export2html_all($recipe_hash, $ingredient_hash, $max_rid, $html_dir, $rel_picdir);
