-- Query B: Index nested-loop join plan

SET enable_nestloop TO on;
SET enable_indexscan TO on;
SET enable_mergejoin TO off;
SET enable_hashjoin TO off;

-- The variable :v controls the selectivity of selection predicate
EXPLAIN (ANALYZE, BUFFERS) 
SELECT z FROM s WHERE  EXISTS (SELECT * FROM r WHERE r.a = s.y AND r.b <= :v);

