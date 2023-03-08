#### test how to save images from db

use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );


use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my $sth = Local::Modulino::DB2JSON->fetch_images($dbh);

my %id2thumb;
my %id2image;

while (my ($id, $image, $thumb) = $sth->fetchrow()) {
  if ($image) {
    $id2image{$id} = $image;
  }
  if ($thumb) {
    $id2thumb{$id} = $thumb;
  }
}

print STDERR "Number of recipes with images: ", scalar keys %id2image, " \n";
print STDERR "Number of recipes with thumbs: ", scalar keys %id2thumb, " \n";

# use File::Temp qw/tempfile tempdir/;
# $File::Temp::KEEP_ALL = 1;
use Cwd;


my $count = 0;

my $oldcwd = getcwd();

my $tmp_img_dir = 'tmp_img';
mkdir $tmp_img_dir, 0755;
chdir $tmp_img_dir;

foreach my $id (keys %id2image) {
  open my $fh, '>', "$id.jpg" or die $!;
  binmode $fh;
  print $fh $id2image{$id};
  close $fh;
}

chdir $oldcwd;

my $tmp_thumb_dir = 'tmp_thumb';
mkdir $tmp_thumb_dir, 0755;
chdir $tmp_thumb_dir;

foreach my $id (keys %id2thumb) {
  open my $fh, '>', "$id.jpg" or die $!;
  binmode $fh;
  print $fh $id2thumb{$id};
  close $fh;
}

chdir $oldcwd;

$dbh->disconnect();


