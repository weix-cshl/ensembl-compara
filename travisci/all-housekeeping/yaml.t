# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use File::Spec;
use Test::More;

use Bio::EnsEMBL::Compara::Utils::Test;


my $root   = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
my $config = File::Spec->catfile($root, 'yamllintrc');

sub is_valid_yaml {
    my $filename = shift;

    my @command = ('yamllint', '-c', $config, $filename);
    Bio::EnsEMBL::Compara::Utils::Test::test_command(\@command, "$filename is a valid YAML file");
}

my @all_files = Bio::EnsEMBL::Compara::Utils::Test::find_all_files();

foreach my $f (@all_files) {
    if ($f =~ /\.ya?ml$/) {
        is_valid_yaml($f);
    }
}

done_testing();

