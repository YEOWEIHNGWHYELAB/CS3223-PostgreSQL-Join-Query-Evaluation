-- Query A: Hash join plan

SET enable_nestloop TO off;
SET enable_indexscan TO off;
SET enable_mergejoin TO off;
SET enable_hashjoin TO on;

-- The variable :v controls the selectivity of selection predicate
EXPLAIN (ANALYZE, BUFFERS) 
SELECT r.c, s.z FROM r JOIN s ON r.a = s.y WHERE r.b <= :v;

