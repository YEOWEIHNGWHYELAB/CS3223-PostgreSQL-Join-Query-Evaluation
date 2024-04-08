-- Query C: Sort-merge join plan

SET enable_nestloop TO off;
SET enable_indexscan TO off;
SET enable_mergejoin TO on;
SET enable_hashjoin TO off;

-- The variable :v controls the selectivity of selection predicate
EXPLAIN (ANALYZE, BUFFERS) 
SELECT z FROM s WHERE NOT  EXISTS (SELECT * FROM r WHERE r.a = s.y AND r.b <= :v);
