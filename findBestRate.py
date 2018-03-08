import sys

f = open('foo.txt', 'r')
lines = f.readlines ()
ordered = []
for i in range(0, len(lines)):
    if i % 2 == 0:
        ordered.append (lines[i])
for i in ordered:
    sys.stdout.write (i)

#WM, CM, EM, EB, WB, AG
#[5 33 39 23 0 0]
