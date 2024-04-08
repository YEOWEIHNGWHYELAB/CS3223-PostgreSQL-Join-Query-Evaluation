#/usr/bin/env bash

# script to plot graphs using gnuplot

cat <<EOF | gnuplot
# Experiment 1a
set terminal pdf
set output "pdf/q1a.pdf"
set title "Effect of selectivity factor on Query a (||r|| = 10^5, join factor = 10)"
set xlabel "Selectivity of selection predicate (%)"
set ylabel "Execution time (ms)"
plot \
"< awk -F, '/inlj-r,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-a.txt" title "inlj-r" with linespoints, \
"< awk -F, '/inlj-s,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-a.txt" title "inlj-s" with linespoints, \
"< awk -F, '/smj,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-a.txt" title "smj" with linespoints, \
"< awk -F, '/smj-r,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-a.txt" title "smj-r" with linespoints, \
"< awk -F, '/smj-s,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-a.txt" title "smj-s" with linespoints, \
"< awk -F, '/hj,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-a.txt" title "hj" with linespoints

# Experiment 1b
set terminal pdf
set output "pdf/q1b.pdf"
set title "Effect of selectivity factor on Query b (||r|| = 10^5, join factor = 10)"
set xlabel "Selectivity of selection predicate (%)"
set ylabel "Execution time (ms)"
plot \
"< awk -F, '/inlj-r,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-b.txt" title "inlj-r" with linespoints, \
"< awk -F, '/inlj-s,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-b.txt" title "inlj-s" with linespoints, \
"< awk -F, '/smj,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-b.txt" title "smj" with linespoints, \
"< awk -F, '/smj-r,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-b.txt" title "smj-r" with linespoints, \
"< awk -F, '/smj-s,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-b.txt" title "smj-s" with linespoints, \
"< awk -F, '/hj,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-b.txt" title "hj" with linespoints

# Experiment 1c
# inlj-s omitted from graph !
set terminal pdf
set output "pdf/q1c.pdf"
set title "Effect of selectivity factor on Query c (||r|| = 10^5, join factor = 10)"
set xlabel "Selectivity of selection predicate (%)"
set ylabel "Execution time (ms)"
plot \
"< awk -F, '/inlj-r,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-c.txt" title "inlj-r" with linespoints, \
"< awk -F, '/smj,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-c.txt" title "smj" with linespoints, \
"< awk -F, '/smj-r,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-c.txt" title "smj-r" with linespoints, \
"< awk -F, '/smj-s,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-c.txt" title "smj-s" with linespoints, \
"< awk -F, '/hj,/ {print \$6*100.0/100000 \" \" \$7 }' output/expt-1-c.txt" title "hj" with linespoints

EOF
