#! /usr/bin/perl -w

# Usage:
#
#   use AddFiles;
#
#   exported functions:
#     AddFiles(dir, file_list, ext_dir, tag);

=head1 AddFiles

C<AddFiles.pm> is a perl module that can be used to extract files from
rpms. It exports the following symbols:

=over

=item *

C<AddFiles(dir, file_list, ext_dir, tag)>

=back

=head2 Usage

use AddFiles;

=head2 Description

=over

=item *

C<AddFiles(dir, file_list, ext_dir, tag)>

C<AddFiles> extracts the files in C<file_list> and puts them into C<dir>.
Files that are not to be taken from rpms are copied from C<ext_dir>.

The syntax of the file list is rather simple; please have a look at those
provided with this package to see how it works. A syntax description follows
later...

On any failure, C<exit( )> is called.


=back

=cut


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
require Exporter;
@ISA = qw ( Exporter );
@EXPORT = qw ( AddFiles );

use strict 'vars';
use integer;

use ReadConfig;

sub AddFiles
{
  local $_;
  my ($dir, $file_list, $ext_dir, $arch, $if_val, $tag);
  my ($rpms, $tdir, $tfile, $p, $r, $d, $u, $g, $files);
  my ($mod_list, @mod_list, %mod_list);
  my ($inc_file, $inc_it, $debug, $eshift);

  ($dir, $file_list, $ext_dir, $tag, $mod_list) = @_;

  $debug = "";
  $debug = $ENV{'debug'} if exists $ENV{'debug'};

  if(!$AutoBuild) {
    $rpms = "$ConfigData{suse_base}/suse";
    die "$Script: where are the rpms?" unless $ConfigData{suse_base} && -d $rpms;
    $rpms = "$rpms/*";
  }
  else {
    $rpms = $AutoBuild;
    die "$Script: where are the rpms?" unless -d $rpms;
    print "running in autobuild environment\n"
  }

  if(! -d $dir) {
    die "$Script: failed to create $dir ($!)" unless mkdir $dir, 0755;
  }

  $tdir = "${TmpBase}.dir";
  die "$Script: failed to create $tdir ($!)" unless mkdir $tdir, 0777;
  $tfile = "${TmpBase}.afile";

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # now we really start...

  die "$Script: no such file list: $file_list" unless open F, $file_list;

  $arch = `uname -m`; chomp $arch;
  $arch = "ix86" if $arch =~ /^i\d86$/;

  $tag = "" unless defined $tag;

  $if_val = 0;

  $eshift = 1;

  while($_ = $inc_it ? <I> : <F>) {
    if($inc_it && eof(I)) {
      undef $inc_it;
      close I;
    }

    chomp;
    next if /^(\s*|\s*#.*)$/;

    s/^\s*//;

    if($debug =~ /\bif\b/) {
      printf ".<%x>%s\n", $if_val, $_;
    }

    s/<kernel_ver>/$ConfigData{kernel_ver}/g;
    s/<kernel_rpm>/$ConfigData{kernel_rpm}/g;
    s/<kernel_img>/$ConfigData{kernel_img}/g;

    if(/^endif/) { $if_val >>= $eshift; next }

    if(/^else/) { $if_val ^= 1; next }

    if(/^ifarch\s+/)  { $if_val <<= 1; $if_val |= 1 if !/\b$arch\b/ || $arch eq ""; next }
    if(/^ifnarch\s+/) { $if_val <<= 1; $if_val |= 1 if  /\b$arch\b/ && $arch ne ""; next }
    if(/^ifdef\s+/)   { $if_val <<= 1; $if_val |= 1 if !/\b$tag\b/  || $tag  eq ""; next }
    if(/^ifndef\s+/)  { $if_val <<= 1; $if_val |= 1 if  /\b$tag\b/  && $tag  ne ""; next }
    if(/^ifabuild/)   { $if_val <<= 1; $if_val |= 1 if !$AutoBuild;                 next }
    if(/^ifnabuild/)  { $if_val <<= 1; $if_val |= 1 if  $AutoBuild;                 next }
    if(/^ifenv\s+(\S+)\s+(\S+)/)  { $if_val <<= 1; $if_val |= 1 if $ENV{$1} ne $2;  next }
    if(/^ifnenv\s+(\S+)\s+(\S+)/) { $if_val <<= 1; $if_val |= 1 if $ENV{$1} eq $2;  next }

    if(/^(els)?if\s+(.+)/) {
      no integer;

      my ( $re, $i, $re0, $val );
      my ( $eif );

      $eif = $1 ? 1 : 0;
      $eshift = 1 if !$eif;
      $re = $2;
      $re0 = $re;
      $re0 =~ s/(('[^']*')|("[^"]*")|\b(defined|lt|gt|le|ge|eq|ne|cmp|not|and|or|xor)\b|(\(|\)))/' ' x length($1)/ge;
      while($re0 =~ s/^((.*)(\b[a-zA-Z]\w+\b))/$2 . (' ' x length($3))/e) {
#        print "    >>$3<<\n";
        $val = "\$ENV{'$3'}";
        $val = '$arch' if $3 eq 'arch';
        $val = '$AutoBuild' if $3 eq 'abuild';
        substr($re, length($2), length($3)) = $val;
      }
      if($debug =~ /\bif\b/) {
#        printf "      <%s>\n", $re0;
        printf "    eval \"%s\"\n", $re;
      }
      $i = eval "if($re) { 0 } else { 1 }";
      die "$Script: sytax error in 'if' statement" unless defined $i;
      $if_val ^= 1 if $eif;
      $if_val <<= 1; $if_val |= $i;
      $eshift++ if $eif;
      next
    }

    next if $if_val;

    if($debug =~ /\bif\b/) {
      printf "*<%x>%s\n", $if_val, $_;
    }

    if(/^include\s+(\S+)$/) {
      die "$Script: recursive include not supported" if $inc_it;
      $inc_file = $1;
      die "$Script: no such file list: $inc_file" unless open I, "$ext_dir/$inc_file";
      $inc_it = 1;
    }
    elsif(/^(\S+):\s*$/) {
      $p = $1;

#      if($AutoBuild) {
#        SUSystem "rm -rf $tdir" and
#          die "$Script: failed to remove $tdir";
#        die "$Script: failed to create $tdir ($!)" unless mkdir $tdir, 0777;
##        SUSystem "sh -c 'cd / ; rpm -ql $p | tar -T - -cf - | tar -C $tdir -xpf -'" and
##          die "$Script: failed to extract $p";
#        print "adding package $p...\n";
#        SUSystem "sh -c 'cd $tdir ; rpm -ql $p | cpio --quiet -o 2>/dev/null | cpio --quiet -dimu --no-absolute-filenames'" and
#          die "$Script: failed to extract $r";
#      }
#      else {

      if($p =~ /^\//) {
        $r = $p;
        die "$Script: no such package: $r" unless -f $r;
      }
      else {
        $r = `echo -n $rpms/$p.rpm`;
        die "$Script: no such package: $p.rpm" unless -f $r;
      }
      print "adding package $p...\n" if $AutoBuild || $debug =~ /\bpkg\b/;
      SUSystem "rm -rf $tdir" and
        die "$Script: failed to remove $tdir";
      die "$Script: failed to create $tdir ($!)" unless mkdir $tdir, 0777;
      SUSystem "sh -c 'cd $tdir ; rpm2cpio $r | cpio --quiet -dimu --no-absolute-filenames'" and
        die "$Script: failed to extract $r";

#      }

    }
    elsif(!/^[a-zA-Z]\s+/ && /^(.*)$/) {
      $files = $1;
      $files =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c '( cd $tdir; tar -cf - $files ) | tar -C $dir -xpf -'" and
        die "$Script: failed to copy $files";
    }
    elsif(/^d\s+(.+)$/) {
      $d = $1; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; mkdir -p $d'" and
        die "$Script: failed to create $d";
    }
    elsif(/^t\s+(.+)$/) {
      $d = $1; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; touch $d'" and
        die "$Script: failed to touch $d";
    }
    elsif(/^r\s+(.+)$/) {
      $d = $1; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; rm -rf $d'" and
        die "$Script: failed to remove $d";
    }
    elsif(/^S\s+(.+)$/) {
      $d = $1; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; strip $d'" and
        die "$Script: failed to strip $d";
    }
    elsif(/^l\s+(\S+)\s+(\S+)$/) {
      SUSystem "ln $dir/$1 $dir/$2" and
        die "$Script: failed to link $1 to $2";
    }
    elsif(/^s\s+(\S+)\s+(\S+)$/) {
      SUSystem "ln -s $1 $dir/$2" and
        die "$Script: failed to symlink $1 to $2";
    }
    elsif(/^m\s+(\S+)\s+(\S+)$/) {
      SUSystem "cp -a $tdir/$1 $dir/$2" and
        die "$Script: failed to move $1 to $2";
    }
    elsif(/^a\s+(\S+)\s+(\S+)$/) {
      SUSystem "sh -c \"cp -a $tdir/$1 $dir/$2\"" and
        print "$Script: $1 not copied to $2 (ignored)\n";
    }
    elsif(/^p\s+(\S+)$/) {
      SUSystem "patch -d $dir -p0 --no-backup-if-mismatch <$ext_dir/$1 >/dev/null" and
        die "$Script: failed to apply patch $1";
    }
    elsif(/^x\s+(\S+)\s+(\S+)$/) {
      SUSystem "cp -dR $ext_dir/$1 $dir/$2" and
        die "$Script: failed to move $1 to $2";
    }
    elsif(/^X\s+(\S+)\s+(\S+)$/) {
      SUSystem "cp -fdR $1 $dir/$2 2>/dev/null" and
        print "$Script: $1 not copied to $2 (ignored)\n";
    }
    elsif(/^g\s+(\S+)\s+(\S+)$/) {
      SUSystem "sh -c 'gunzip -c $tdir/$1 >$dir/$2'" and
        die "$Script: could not uncompress $1 to $2";
    }
    elsif(/^c\s+(\d+)\s+(\S+)\s+(\S+)\s+(.+)$/) {
      $p = $1; $u = $2; $g = $3;
      $d = $4; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; chown $u.$g $d'" and
        die "$Script: failto to change owner of $d to $u.$g";
      SUSystem "sh -c 'cd $dir; chmod $p $d'" and
        die "$Script: failto to change perms of $d to $p";
    }
    elsif(/^b\s+(\d+)\s+(\d+)\s+(\S+)$/) {
      SUSystem "mknod $dir/$3 b $1 $2" and
        die "$Script: failto to make block dev $3 ($1, $2)";
    }
    elsif(/^C\s+(\d+)\s+(\d+)\s+(\S+)$/) {
      SUSystem "mknod $dir/$3 c $1 $2" and
        die "$Script: failto to make char dev $3 ($1, $2)";
    }
    elsif(/^M\s+(\S+)\s+(\S+)$/) {
      SUSystem "sh -c \"cp -av $tdir/$1 $dir/$2\" >$tfile" and
        print "$Script: $1 not copied to $2 (ignored)\n";

      my ($f, $g);
      for $f (`cat $tfile`) {
        if($f =~ /\s->\s$dir\/(.*)\n?$/) {
          $g = $1; $g =~ s/^\/*//;
          push @mod_list, "$g\n" unless exists $mod_list{$g};
          $mod_list{$g} = 1;
        }
      }
    }
    else {
      die "$Script: unknown entry: \"$_\"\n";
    }

  }

  close F;

  SUSystem "rm -rf $tdir";
  SUSystem "rm -f $tfile";

  if(@mod_list && $mod_list) {
    open F, ">$mod_list";
    print F @mod_list;
    close F;
  }

  return 1;
}

1;
