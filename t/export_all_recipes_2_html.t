use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $json = read_file('recipes.json', { binmode => ':raw' });
my $recipe_hash = decode_json($json);

$json = read_file('ingredients.json', { binmode => ':raw' });
my $ingredient_hash = decode_json($json);


#### extract max recipe id (shows which recipes are older/newer)
use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

my $max_rid = Local::Modulino::GourmetExport->get_max_id($dbh);
print STDERR "Max recipe id: $max_rid\n";

#### No longer need to access db, disconnect
$dbh->disconnect();

#### picture directory in html file: has to be relative to where the html file is
my $html_dir = 'html_export';
my $rel_picdir = 'pics';

########################################
### create html documents for all recipes in db
########################################

my $nbr_recipes = scalar(keys %{ $recipe_hash });
print STDERR "Total number of recipes: $nbr_recipes\n";

Local::Modulino::GourmetExport->export2html_all($recipe_hash, $ingredient_hash, $max_rid, $html_dir, $rel_picdir);
