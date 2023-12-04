#### test how dates/time stamps are stored in the db

use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

#### date fields: last_access in info, last_modified in recipe, both INTEGER data types
