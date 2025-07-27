#!/bin/sh

# Enter urls to your goodreads rss feed below.
# -> Find it by navigating to one of your goodreads shelves and
# clicking the "RSS" button at the bottom of the page.

# url for "Currently reading":
readingurl="https://www.goodreads.com/review/list_rss/176913806?key=ij6FlDffUwmN8UEhNnLYPk0ln4fWPvaqAZTkc2wLwZ-fcaTM&shelf=currently-reading"
# url for "Read":
readurl="https://www.goodreads.com/review/list_rss/176913806?key=ij6FlDffUwmN8UEhNnLYPk0ln4fWPvaqAZTkc2wLwZ-fcaTM&shelf=read"

# Enter the path to your Vault
vaultpath="G:\My Drive\personal\Second Brain\100 Reference notes"

# Get current date and assign to variable
year=$(date +%Y) # yyyy
nummonth=$(date +%m) # mm
month=$(date +%B) # Mon

# Grabs the data from the currently reading rss feed and removes all HTML and tabs
# sed -e 's/contenttoreplace/contenttoinsert/'
IFS=$'\n' readingfeed=$(curl --silent "$readingurl" | \
egrep 'title|book_large_image_url|author_name|book_published|book_id' | \
sed -e 's/<!\[CDATA\[//' -e 's/\]\]>//' \
-e 's/Nikolaj.s Bookshelf: currently-reading//' \
-e 's/<book_large_image_url>//' -e 's/<\/book_large_image_url>/ | /' \
-e 's/<title>//' -e 's/<\/title>/ | /' \
-e 's/<author_name>//' -e 's/<\/author_name>/ | /' \
-e 's/<book_published>//' -e 's/<\/book_published>/ | /' \
-e 's/<book_id>//' -e 's/<\/book_id>/ | /' \
-e 's/^[ \t]*//' -e 's/[ \t]*$//' | \
tail +3 | \
fmt -u
)

# Grab the bookid from READ data from the url and format it
IFS=$'\n' readfeed=$(curl --silent "$readurl" | egrep 'book_id' | \
sed -e 's/<book_id>//' -e 's/<\/book_id>/ | /' \
-e 's/^[ \t]*//' -e 's/[ \t]*$//' | \
fmt
)

# Turn the data into an array, by substituting '|' for a new-line character
readingarr=($(echo $readingfeed | tr "|" "\n")) # outer pair of brackets is necessary for array definition
readarr=($(echo $readfeed | tr "|" "\n"))

# Remove tabs at the beginning and end of item
for (( i = 0 ; i < ${#readingarr[@]} ; i++ ))
do
  readingarr[$i]=$(echo "${readingarr[$i]}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
done
for (( i = 0 ; i < ${#readarr[@]} ; i++ ))
do
  readarr[$i]=$(echo "${readarr[$i]}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
done

# Get the amount of books by dividing array by 5
readingamount=$(expr "${#readingarr[@]}" / 5)

for (( i = 0 ; i < ${readingamount} ; i++ ))
do
  # Create a temporary counter to loop through books
  # Multiplied by 5 because there are five fields
  counter=$(expr "$i" \* 5)

  # Sets bookid
  bookid=${readingarr[$(expr "$counter" + 1)]}

  # grep scans the whole note for an appearance of bookid
  if grep -q "${bookid}" -r "${vaultpath}"
    then
      # code if found
      unset readingarr["$counter"]
      unset readingarr[$(expr "$counter" + 1)]
      unset readingarr[$(expr "$counter" + 2)]
      unset readingarr[$(expr "$counter" + 3)]
      unset readingarr[$(expr "$counter" + 4)]
      echo "Book '${readingarr["$counter"]}' already exists"
  fi
done

# readingarr now might have gaps, because of unset values
# Creates an updated array with no gaps
for i in "${!readingarr[@]}"
do
    new_array+=( "${readingarr[i]}" )
done
readingarr=("${new_array[@]}")
unset new_array

# Get the amount of books by dividing array by 5
readingamount=$(expr "${#readingarr[@]}" / 5)

# TODO continue from here on
if (( "$readingamount" == 0 ))
  then
  echo "Currently Reading: No new books found."
fi

# Start the loop for each book
for (( i = 0 ; i < ${readingamount} ; i++ ))
do

  counter=$(expr "$i" \* 5)

  # Set variables
  title=${readingarr["$counter"]}
  bookid=${readingarr[$(expr "$counter" + 1)]}
  imglink=${readingarr[$(expr "$counter" + 2)]}
  author=${readingarr[$(expr "$counter" + 3)]}
  pub=${readingarr[$(expr "$counter" + 4)]}


# Delete illegal (':' and '/') and unwanted ('#') characters
cleantitle=$(echo "${title}" | sed -e 's/\\//' -e 's/:\ –/' -e 's/#/\')

  # Write the contents for the book file

  if [[ "$cleantitle" == "" ]];
  then
    echo "Error! Failed to create note due to empty array."
  else
    echo "---
bookid: ${bookid}
---
links: [[Books]]
status: #book, #currently-reading
tags: 

# ${title}

![b|150](${imglink})

* Universe/Series: ADD SERIES
* Author: [[${author}]]
* Year published: [[${pub}]]



---
# References" >> "${vaultpath}\\${cleantitle}.md"
    # Display a notification when creating the file
    echo "display notification \"Booknote created!\" with title \"${cleantitle//\"/\\\"}\""
  fi

done

ifbookid=$(find "${vaultpath}" -type f -print0 | xargs -0 grep -li "${cbookid}")
ifcurrread=$(find "${vaultpath}" -type f -print0 | xargs -0 grep -li "#currently-reading")

if find "${vaultpath}" -type f -print0 | xargs -0 grep -li "${cbookid}"
then
  # Code if found: update read books
  fname=$(find "${vaultpath}" -type f -print0 | xargs -0 grep -li "${cbookid}")
  sed -i '' "/Year published: \[\[[0-9][0-9][0-9][0-9]\]\]/ a\\
  \* Year read: #read${year}" "$fname"
  sed -i '' "/Year read: #read${year}/ a\\
  \* Month read: [[${year}-${nummonth}-${month}|${month} ${year}]]" "$fname"
  sed -i '' -e 's/#currently-reading/#read/' "$fname"

  # Grab the name of the changed book
  fname=$(echo ${fname} | sed 's/^.*\///' | sed 's/\.[^.]*$//')
  echo "Updated read books ${fname}"
else
 # code if not found: No new books
 echo "Read: No new read books."
fi

for (( i = 0 ; i < ${#readarr[@]} ; i++ ))
do
  #circle through bookid array
  cbookid=${readarr["$i"]}

  # If in the path to the vault, there is a file with the current id, then …
  if find "${vaultpath}" -not -path "*\\\.*" -type f \( -iname "*.md" \) -print0 | xargs -0 grep -li "${cbookid}"
  then
  # … set variable fname to that file
  fname=$(find "${vaultpath}" -not -path "*\\\.*" -type f \( -iname "*.md" \) -print0 | xargs -0 grep -li "${cbookid}")
    # Check if it has tag "#currently-reading"
      if grep "#currently-reading" "${fname}"
      then
        # If yes, change the formatting, delete the "#currently-reading" tag
        sed -i '' "/Year published: \[\[[0-9][0-9][0-9][0-9]\]\]/ a\\
        \* Year read: #read${year}" "$fname"
        sed -i '' "/Year read: #read${year}/ a\\
        \* Month read: [[${year}-${nummonth}-${month}|${month} ${year}]]" "$fname"
        sed -i '' -e 's/#currently-reading/#outline \/ #welcome/' "$fname"

        # Grab the name of the changed book
        declare -i updatedbooks; updatedbooks+=1
        fname=$(echo ${fname} | sed 's/^.*\///' | sed 's/\.[^.]*$//')
        # Show notification
        echo -e "Updated read books ${fname}"
      fi
  fi
done

# code if not found: No new books
if [[ ${updatedbooks} = "" ]]
then
echo "No new read books."
fi
