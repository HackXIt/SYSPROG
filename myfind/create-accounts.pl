#!/usr/bin/perl
#
# Description: This script
# - loads /etc/{passwd,shadow,group,gshadow}
# - removes our old entries (which are identified by the $gecos in the
#   gecos field)
# - checks that the new entries and the $not_used_uid do not clash with
#   existing entries
# - adds the new users and groups (see %users below)
# - and writes the result (sorted by id) into /etc/{passwd,shadow,group,gshadow}-new
#
# Intrinsically, the script checks if the gids in /etc/passwd actually exist in
# /etc/group and throws perl errors if they don't (because I'm lazy, that shouldn't
# actually happen and it can be fixed by hand trivially anyways).
#
# Please check the contents and do
#
# for file in passwd shadow group gshadow; do
#      mv /etc/$file-new /etc/$file;
# done;
# chmod a= /etc/shadow /etc/gshadow
#
# Use at your own risk! Backup the original files before - just in case.
# Check the original permissions of the files!
#
# Obviously, the script must be run as root (or you copy the input files,
# chown them and fix the paths in this script).
#
# `useradd`, `adduser` etc. have sanity checks which inhibit pure
# numerical and/or too long usernames - for good reason in the real life.
# However, we want to study more interesting things than "user joe";-)
#

use strict;
use warnings;

my $gecos = "test-env-for-find";
my $not_used_uid = 999999;

# to be created users and groups. the key is the name and value is the id (obviously;-)
my %users = (
             'karl' => 160,
	     '160' => 150,
	     'd836154a1ba14015bff78dad09f7dd82b41cd39c2a1347598215ad0622e87d03d2cc91334a4e4d8e9a5b4f35a8650d2cf5a6711d86de4b1bb227eb8ccb58bcf9197878c566d84050ae7f1aca5c6b97ab' => 161,
	     'x%sx%px%n' => 162,
	    );

sub load_file($) {
    my ($name) = @_;

    my @rv;
    open(F, '<'.$name) || die 'Cannot open "'.$name.'" to read: '.$!;
    foreach (<F>) {
        chomp;
        next if /^\s*$/;
        my @field = (split /:/);
        while (s/:$//) {  # an ':' at the end of the line doeasn't yield an empty string at the end
            push @field, "";
        }
        push @rv, \@field;
    }
    close(F);
    return @rv;
}

sub save_file($$) {
    my ($name, $data) = @_;
    open(F, '>'.$name) || die 'Cannot open "'.$name.'" to write: '.$!;
    foreach (@{$data}) {
        print F join(':', @{$_})."\n";
    }
    close(F);
}

#############################
#
# load all
#
my @passwd = load_file('/etc/passwd');
my @shadow = load_file('/etc/shadow');
my @group = load_file('/etc/group');
my @gshadow = load_file('/etc/gshadow');

my %uid_to_del;
my %gid_to_del;
my %username_to_del;
my %groupname_to_del;
# remove old entried from passwd and store the name
my @new;
while (my $i = pop @passwd) {
    if ($i->[4] eq $gecos) {
        $username_to_del{$i->[0]} = $uid_to_del{$i->[3]} = $gid_to_del{$i->[0]} = $gid_to_del{$i->[4]} = 1;
        print STDERR 'deleting user '.$i->[0].' from passwd'."\n";
    } else {
        push @new, $i;
    }
}
@passwd = @new;

# remove old from shadow
@new = ();
while (my $i = pop @shadow) {
    if (exists $username_to_del{$i->[0]}) {
        print STDERR 'deleting user '.$i->[0].' from shadow'."\n";
    } else {
        push @new, $i;
    }
}
@shadow = @new;

# remove old from group
@new = ();
while (my $i = pop @group) {
    if (exists $gid_to_del{$i->[2]} or exists $gid_to_del{$i->[0]}) { # check for numeric and textual groups in /etc/passwd
        $groupname_to_del{$i->[0]} = 1;
        print STDERR 'deleting group '.$i->[0].' from group'."\n";
    } else {
        push @new, $i;
    }
}
@group = @new;

# remove old from gshadow
@new = ();
while (my $i = pop @gshadow) {
    if (exists $groupname_to_del{$i->[0]}) {
        print STDERR 'deleting group '.$i->[0].' from gshadow'."\n";
    } else {
        push @new, $i;
    }
}
@gshadow = @new;

# check for clashes
my $errors = 0;
foreach my $name (keys %users) {
    my $id = $users{$name};
    if (grep { $_->[0] eq $name } @passwd) {
        print 'Username "'.$name.'" exist already in /etc/passwd'."\n"; ++$errors;
    }
    if (grep { $_->[2] eq $id   } @passwd) {
        print 'Userid "'.$id.'" exist already in /etc/passwd'."\n"; ++$errors;
    }
    if (grep { $_->[0] eq $name } @shadow) {
        print 'Username "'.$name.'" exist already in /etc/shadow'."\n"; ++$errors;
    }
    if (grep { $_->[0] eq $name } @group) {
        print 'Groupname "'.$name.'" exist already in /etc/group'."\n"; ++$errors;
    }
    if (grep { $_->[2] eq $id   } @group) {
        print 'Groupid "'.$id.'" exist already in /etc/group'."\n"; ++$errors;
    }
    if (grep { $_->[0] eq $name } @gshadow) {
        print 'Groupname "'.$name.'" exist already in /etc/gshadow'."\n"; ++$errors;
    }
}
exit(1) if $errors > 0;

# create new accounts
foreach my $name (keys %users) {
    my $id = $users{$name};
    push @passwd,  [ $name, 'x', $id, $id, $gecos, '/home/'.$name, '/bin/bash' ];
    push @shadow,  [ $name, 'x', '17491', '0', '99999', '7', '', '', '' ];
    push @group,   [ $name, 'x', $id, '' ];
    push @gshadow, [ $name, '!', '', '' ];
}

# sort them
@passwd = sort { $a->[2] <=> $b->[2] } @passwd; # sort by uid
my %passwd;
foreach (@passwd) {
    $passwd{$_->[0]} = $_->[2];
    #  print STDERR $_->[0]." -> ".$_->[2]."\n";
}
@shadow = sort {
    #  print STDERR $a->[0]." <=> ".$b->[0]."\n";
    $passwd{$a->[0]} <=> $passwd{$b->[0]} } @shadow; # sort by name identical to passwd

@group = sort { $a->[2] <=> $b->[2] } @group; # sort by gid
my %group;
foreach (@group) {
    $group{$_->[0]} = $_->[2];
}
@gshadow = sort {
    #  print STDERR $a->[0]." <=> ".$b->[0]."\n";
    $group{$a->[0]} <=> $group{$b->[0]} } @gshadow; # sort by name identical to passwd


# save all
save_file('/etc/passwd-new', \@passwd);
save_file('/etc/shadow-new', \@shadow);
save_file('/etc/group-new', \@group);
save_file('/etc/gshadow-new', \@gshadow);
