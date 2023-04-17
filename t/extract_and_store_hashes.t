use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

### generate html files for some recipes - given by ids

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my $test_ids = [
  '1302', # recipe w/ other recipe as ingredient
#  '1301', # refered by 1302
  '1305', # also refers to 1301
  '175',  # refers to 40
  '246', # recipe w/ ingredient subgroups
  '1185', # recipe w/ optional ingredients
  '1877', # recipe w/ image
  '1013', 
 '92',   # recipe w/o image, w/ link, cuisine
  '1485', # recipe w/o image, link, cuisine
  # w/ yield, preptime, cooktime, category, rating, source
  ];


#### collect data for recipe ids from database

my ($recipe_hash, $ingredient_hash) = Local::Modulino::DB2JSON->export2html_collect_data($dbh, $test_ids);

#### variables/constants needed for storing
####  - html files
####  - images
####  - names of image files 

my $html_dir = 'tests';
my $pic_dir = "$html_dir/pics";

$recipe_hash = Local::Modulino::DB2JSON->export2html_collect_images($dbh, $recipe_hash, $html_dir, $pic_dir);

my $max_rid = Local::Modulino::DB2JSON->get_max_id($dbh);
print STDERR "Max recipe id: $max_rid\n";

$dbh->disconnect();

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $json = encode_json($recipe_hash);
write_file('recipes.json', { binmode => ':raw' }, $json);

$json = read_file('recipes.json', { binmode => ':raw' });
my $recipe_hash_reloaded = decode_json($json);


is_deeply($recipe_hash, $recipe_hash_reloaded, 'hashes should be the same');
