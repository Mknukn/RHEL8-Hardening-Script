#!/bin/bash

##6.1

##6.1.1 Audit system file permissions (Manual)

##6.1.2 Ensure sticky bit is set on all world-writable directories 
 df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null | xargs -I '{}' chmod a+t '{}'
 echo "Sticky bit  is set, continuing.."

##6.1.3 Ensure permissions on /etc/passwd are configured
chown root:root /etc/passwd
chmod 644 /etc/passwd
stat /etc/passwd
echo "Permissions on /etc/passwd configured, continuing.."

##6.1.4 Ensure permissions on /etc/shadow are configured
chown root:root /etc/shadow
chmod 0000 /etc/shadow
stat /etc/shadow
echo "Permissions on /etc/shadow configured, continuing.."

##6.1.5 Ensure permissions on /etc/group are configured
chown root:root /etc/group
chmod u-x,g-wx,o-wx /etc/group
stat /etc/group
echo "Permissions on /etc/group configured, continuing.."

##6.1.6 Ensure permissions on /etc/gshadow are configured
chown root:root /etc/gshadow
chmod 0000 /etc/gshadow
stat /etc/gshadow
echo "Permissions on /etc/gshadow configured, continuing.."

##6.1.7 Ensure permissions on /etc/passwd- are configured
chown root:root /etc/passwd-
# chmod chmod u-x,go-wx /etc/passwd-
stat /etc/passwd-
echo "Permissions on /etc/passwd- configured, continuing.."

##6.1.8 Ensure permissions on /etc/shadow- are configured
chown root:root /etc/shadow-
chmod 0000 /etc/shadow-
stat /etc/shadow-
echo "Permissions on /etc/shadow- configured, continuing.."

##6.1.9 Ensure permissions on /etc/group- are configured
chown root:root /etc/group-
chmod u-x,go-wx /etc/group-
stat /etc/group-
echo "Permissions on /etc/group- configured, continuing.."

##6.1.10 Ensure permissions on /etc/gshadow- are configured 
chown root:root /etc/gshadow-
chmod 0000 /etc/gshadow-
stat /etc/gshadow-
echo "Permissions on /etc/gshadow- configured, continuing.."

echo "Creating directory for duplicates..."
mkdir duplicates/ # Create a directory that will store duplicates for manual removal

# 6.2.1 Ensure password fields are not empty

awk -F: '($2 == "" ) { print $1 " does not have a password, disabling..."; system(passwd -l $1)}' /etc/shadow

# 6.2.2 Ensure all groups in /etc/passwd exist in /etc/group

for i in $(cut -s -d: -f4 /etc/passwd | sort -u ); 
do 
    grep -q -P "^.*?:[^:]*:$i:" /etc/group 
    if [ $? -ne 0 ]; then 
        echo "Group $i is referenced by /etc/passwd but does not exist in /etc/group"
        
        while : ; do
            echo -n "Do you want to remove group $i (y/n): "
            if [ $answer == "y" ] || [ $answer == "Y" ]; then
                echo "Removing group $i..."
                groupdel $i

            elif [ $answer == "n" ] || [ $answer == "N" ]; then
                echo "Continuing..."
                break
            else
                echo "You entered a wrong option."
            fi

        done
    fi 
done

# 6.2.3 Ensure no duplicate UIDs exist

uid_counter=0
touch duplicates/uid_duplicates

echo -e "This file shows duplicate UIDs within the system\n" >> duplicates/uid_duplicates

cut -f3 -d ":" /etc/passwd | sort -n | uniq -c | while read x ; do 
    [ -z "$x" ] && break 
    set - $x 
    if [ $1 -gt 1 ]; then 
        users=$(awk -F: '($3 == n) { print $1 }' n=$2 /etc/passwd | xargs) 
        echo "Duplicate UID ($2): $users"
        echo "Duplicate UID ($2): $users" >> duplicates/uid_duplicates
        let uid_counter++
    fi 
done

if [ $uid_counter -eq 0 ]; then
    echo "No UID duplicates, continuing..."
fi

# 6.2.4 Ensure no duplicate GIDs exist

gid_counter=0
touch duplicates/gid_duplicates

echo -e "This file shows duplicate GIDs within the system\n" >> duplicates/gid_duplicates

cut -d: -f3 /etc/group | sort | uniq -d | while read x ; do 
    echo "Duplicate GID ($x) in /etc/group"
    echo "Duplicate GID found: $x" >>  duplicates/gid_duplicates  
    let gid_counter++
done

if [ $gid_counter -eq 0 ]; then
    echo "No duplicate GID found, continuing..."
fi

# 6.2.5 Ensure no duplicate user names exist

user_counter=0
touch duplicates/user_duplicates

echo -e "This file shows duplicate user names within the system\n" >> duplicates/user_duplicates

cut -d: -f1 /etc/passwd | sort | uniq -d | while read x; do 
    echo "Duplicate login name ${x} in /etc/passwd"
    echo "Duplicate login name: ${x}" >> duplicates/user_duplicates
    let user_counter++
done

if [ $user_counter -eq 0 ]; then
    echo "No duplicate user names found, continuing..."
fi

# 6.2.6 Ensure no duplicate group names exist

group_name_counter=0
touch duplicates/group_duplicates

echo -e "This file shows duplicate group names within the system\n" >> duplicates/group_duplicates

cut -d: -f1 /etc/group | sort | uniq -d | while read -r x; do 
    echo "Duplicate group name ${x} in /etc/group"
    echo "Duplicate group name: ${x}" >> duplicates/group_duplicates
done

if [ $group_name_counter -eq 0 ]; then
    echo "No duplicate group names found, continuing..."
fi

# 6.2.7 Ensure root PATH Integrity

RPCV="$(sudo -Hiu root env | grep '^PATH=' | cut -d= -f2)" 

echo "$RPCV" | grep -q "::" && echo "root's path contains a empty directory (::)" 
echo "$RPCV" | grep -q ":$" && echo "root's path contains a trailing (:)" 

for x in $(echo "$RPCV" | tr ":" " "); do 

    if [ -d "$x" ]; then 

    ls -ldH "$x" | awk '$9 == "." {print "PATH contains current working directory (.)"} $3 != "root" {print $9, "is not owned by root"} substr($1,6,1) != "-" {print $9, "is group writable"} substr($1,9,1) != "-" {print $9, "is world writable"}' 

    else 

    echo "$x is not a directory" 
    fi

done

# 6.2.8 Ensure root is the only UID 0 account

root_uid_check=$(awk -F: '($3 == 0) { print $1 }' /etc/passwd)

if [ $(awk -F: '($3 == 0) { print $1 }' /etc/passwd | wc -l) -eq 1 ]; then
    echo "Root is only user with UID of 0, continuing..."
else
    for user in $root_uid_check
    do
        if [ $user != "root" ]; then
             while : ; do
                echo -n "$user has UID of 0 but is not root, do you want to remove it (y/n): "
                if [ $answer == "y" ] || [ $answer == "Y" ]; then
                    echo "Removing user $user..."
                    userdel $user

                elif [ $answer == "n" ] || [ $answer == "N" ]; then
                    echo "Continuing..."
                    break
                else
                    echo "You entered a wrong option."
                fi
            done
        fi
    done
fi
        
##6.2.9 Ensure all users' home directories exist (Automated)##

if 
awk -F: '($1!~/(halt|sync|shutdown|nfsnobody)/ &&
$7!~/^(\/usr)?\/sbin\/nologin(\/)?$/ && $7!~/(\/usr)?\/bin\/false(\/)?$/) {
print $1 " " $6 }' /etc/passwd | while read -r user dir; do
 if [ ! -d "$dir" ]; then
 mkdir "$dir"
 chmod g-w,o-wrx "$dir"
 chown "$user" "$dir"
 fi
done; then

echo "Configured all user's home directories... "

fi

##6.2.10 Ensure users own their home directories(Automated)##

if
awk -F: '($1!~/(halt|sync|shutdown|nfsnobody)/ &&
$7!~/^(\/usr)?\/sbin\/nologin(\/)?$/ && $7!~/(\/usr)?\/bin\/false(\/)?$/) {
print $1 " " $6 }' /etc/passwd | while read -r user dir; do
 if [ ! -d "$dir" ]; then
 echo "User: \"$user\" home directory: \"$dir\" does not exist, creating
home directory"
 mkdir "$dir"
 chmod g-w,o-rwx "$dir"
 chown "$user" "$dir"
 else
 owner=$(stat -L -c "%U" "$dir")
 if [ "$owner" != "$user" ]; then
 chmod g-w,o-rwx "$dir"
 chown "$user" "$dir"
 fi
 fi
done; then 

echo "Configured users own their home directories..."

fi

##6.2.13 Ensure users' .netrc Files are not group or world accessible(Automated)##

{
awk -F: '($1!~/(halt|sync|shutdown|nfsnobody)/ &&
$7!~/^(\/usr)?\/sbin\/nologin(\/)?$/ && $7!~/(\/usr)?\/bin\/false(\/)?$/) {
print $6 }' /etc/passwd | while read -r dir; do
 if [ -d "$dir" ]; then
 file="$dir/.netrc"
 [ ! -h "$file" ] && [ -f "$file" ] && rm -f "$file"
fi
done 

echo "Configured users .netrc Files are not group or world accessible..."
}

##6.2.14 Ensure no users have .forward files (Automated)##

{
awk -F: '($1!~/(halt|sync|shutdown|nfsnobody)/ &&
$7!~/^(\/usr)?\/sbin\/nologin(\/)?$/ && $7!~/(\/usr)?\/bin\/false(\/)?$/) {
print $6 }' /etc/passwd | while read -r dir; do
 if [ -d "$dir" ]; then
 file="$dir/.forward"
 [ ! -h "$file" ] && [ -f "$file" ] && rm -r "$file"
 fi
done

echo "Configured no users have .forward files..."
}

##6.2.15 Ensure no users have .netrc files(Automated)##

{
awk -F: '($1!~/(halt|sync|shutdown|nfsnobody)/ &&
$7!~/^(\/usr)?\/sbin\/nologin(\/)?$/ && $7!~/(\/usr)?\/bin\/false(\/)?$/) {
print $6 }' /etc/passwd | while read -r dir; do
 if [ -d "$dir" ]; then
 file="$dir/.netrc"
 [ ! -h "$file" ] && [ -f "$file" ] && rm -f "$file"
 fi
done

echo "Configured no users have .netrc files"
}

##6.2.16 Ensure no users have .rhosts files (Automated)##

{ 
awk -F: '($1!~/(halt|sync|shutdown|nfsnobody)/ &&
$7!~/^(\/usr)?\/sbin\/nologin(\/)?$/ && $7!~/(\/usr)?\/bin\/false(\/)?$/) {
print $6 }' /etc/passwd | while read -r dir; do
 if [ -d "$dir" ]; then
 file="$dir/.rhosts"
 [ ! -h "$file" ] && [ -f "$file" ] && rm -r "$file"
 fi
done

echo -e "Configured no users have .rhosts files..."
}

