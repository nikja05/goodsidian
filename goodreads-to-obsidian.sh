#!/bin/sh

# Enter URLs to your goodreads rss feed below.
# -> Find it by navigating to one of your goodreads shelves and
# clicking the "RSS" button at the bottom of the page.

# URL for "Currently reading":
readingurl="https://www.goodreads.com/review/list_rss/176913806?key=ij6FlDffUwmN8UEhNnLYPk0ln4fWPvaqAZTkc2wLwZ-fcaTM&shelf=currently-reading"
# URL for "Read":
readurl="https://www.goodreads.com/review/list_rss/176913806?key=ij6FlDffUwmN8UEhNnLYPk0ln4fWPvaqAZTkc2wLwZ-fcaTM&shelf=read"

# enter path to your Vault
vaultpath="G:\My Drive\personal\Second Brain\100 Reference Notes"

# gets current date and assign to variable
year=$(date +%Y) # yyyy
nummonth=$(date +%m) # mm
month=$(date +%B) # Mon

# grabs title, cover image, author name, publishing year and book id
# from 'currently reading' RSS feed and removes all HTML and tabs
# sed syntax: sed -e 's/contenttoreplace/contenttoinsert/'
echo "Getting 'Currently Reading' data."
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
fmt -u # uniform spacing
)

# grabs book id from 'read' RSS feed and removes all HTML and tabs
echo "Getting 'Read' data."
IFS=$'\n' readfeed=$(curl --silent "$readurl" | \
egrep 'book_id' | \
sed -e 's/<book_id>//' -e 's/<\/book_id>/ | /' \
-e 's/^[ \t]*//' -e 's/[ \t]*$//' | \
fmt -u # uniform spacing
)

# turns the data into an array, by substituting '|' for a new-line character
echo "Putting the data into an array."
readingarr=($(echo $readingfeed | tr "|" "\n")) # outer pair of brackets is necessary for array definition
readarr=($(echo $readfeed | tr "|" "\n"))

# removes tabs at the beginning and end of item
for (( i = 0 ; i < ${#readingarr[@]} ; i++ ))
do
  readingarr[$i]=$(echo "${readingarr[$i]}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
done
for (( i = 0 ; i < ${#readarr[@]} ; i++ ))
do
  readarr[$i]=$(echo "${readarr[$i]}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
done

# gets the amount of books by dividing array by 5
readingamount=$((${#readingarr[@]} / 5))

# checks if book is in directory, otherwise removes it
echo "Removing books that already have a note:"
for (( i = 0 ; i < ${readingamount} ; i++ ))
do
  # temporary counter variable
  # multiplication necessary -> 5 fields per book
  counter=$(($i * 5))

  # Sets bookid
  bookid=${readingarr[$(($counter + 1))]}

  # grep scans all notes in vaultpath for an appearance of bookid
  if grep -q "${bookid}" -r "${vaultpath}"; then
    # removes the book from the array
    echo "  '${readingarr[$counter]}'"
    unset readingarr[$counter]
    unset readingarr[$(($counter + 1))]
    unset readingarr[$(($counter + 2))]
    unset readingarr[$(($counter + 3))]
    unset readingarr[$(($counter + 4))]
  fi
done

# readingarr now might have gaps, because of unset values
# creates an updated array with no gaps
echo "Cleaning up the array."
for i in "${!readingarr[@]}"
do
    new_array+=("${readingarr[i]}")
done
readingarr=("${new_array[@]}")
unset new_array

# gets the amount of (remaining) books by dividing array by 5
readingamount=$((${#readingarr[@]} / 5))

if (("$readingamount" == 0)); then
  echo "Currently Reading: No new books found."
  echo
else
  echo "--- Starting Process ---"
  echo
  # creates a note for each book
  for (( i = 0 ; i < ${readingamount} ; i++ ))
  do
    # temporary counter variable
    # multiplication necessary -> 5 fields per book
    counter=$(($i * 5))

    # sets variables
    title=${readingarr[$counter]}
    bookid=${readingarr[$(($counter + 1))]}
    imglink=${readingarr[$(($counter + 2))]}
    author=${readingarr[$(($counter + 3))]}
    published=${readingarr[$(($counter + 4))]}

    # deletes illegal ':' and '/' and unwanted '#' characters
    cleantitle=$(echo "${title}" | sed -e 's/[\\\/:*?"<>|#]//g' -e 's/:\ / - /')

    # time of note creation, cut used for formatting of weekday
    creationdate=$(date +"%a %m-%d-%Y %H:%M" | cut -c1-2,4-)

    # writes the contents for the book file
    if [[ "$cleantitle" == "" ]]; then
      echo "Error! Failed to create note due to faulty title."
      echo
    else
      echo "---
  bookid: '${bookid}'
  ---
  ${creationdate}
  Status: #reference #currently-reading
  Tags: [[Book]]
  Author: [[${author}]]
  Year published: ${published}
  Universe/Series: *ADD SERIES*
  Link to reference:
  # 📚${cleantitle}

  '![Cover|150](${imglink})'

  ---
  " >> "${vaultpath}/${cleantitle}.md"
      # displays a notification when file was created
      echo "Booknote created with title '${cleantitle}'"
      echo
    fi
  done
fi

# if a book was read, change the tag and add read date
echo "--- Updating read books ---"
updatecounter=0
for i in ${!readarr[@]}
do
  # return path of book with matching bookid
  readbookpath=$(find "${vaultpath}" -type f -print0 | xargs -0 grep -li "bookid: '${readarr[$i]}'")

  # add Year read and replace #currently-reading with #read
  if [ "$readbookpath" != "" ]; then
    # if the read book was already marked as read, skip to the next book
    if [ $(echo $(grep -ci "#read" "$readbookpath")) == "0" ]; then
      year=$(date +%Y)
      sed -i -e "/Year published: [0-9][0-9][0-9][0-9]/a Year read: ${year}" "$readbookpath"
      sed -i -e 's/#currently-reading/#read/' "$readbookpath"
      ((updatecounter++))
    fi
  fi
done

# user friendly update message
if (( updatecounter > 1 )); then
  echo "$updatecounter books updated."
elif (( updatecounter == 1 )); then
  echo "1 book updated."
else
  echo "No new read books."
fi