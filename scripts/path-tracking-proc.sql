-- This procedure works with two tables, one for lines and one for points.  It
-- sets up a trigger and procedure to space points equally across a line based
-- on speed and such.
--
-- Required fields:
--
-- Line (name: ship_route)
-- - fid         : id
-- - the_geom    : line-flavored geom
-- - knots       : float, speed
-- - hours_delta : int, distance between points
-- - start_time  : timestamp
--
-- Point (name: ship_position)
-- - the_geom    : point-flavored geom
-- - line_id     : link to layer
-- - time        : timestamp
-- - time_end    : timestamp
CREATE or replace FUNCTION recalc_path_points() RETURNS TRIGGER AS $$
DECLARE
  i integer;
  --
  -- variables that come from the line table
  knots integer := NEW.knots;
  hours_delta integer := NEW.hours_delta;  -- distance between points
  start_time timestamp := NEW.start_time;
  --
  k integer := 1852;  -- multiply by knots to get meters per hour
  --
  meters_delta integer := hours_delta * knots * k;  -- distance between points
  total_meters float := ST_Length(ST_Transform(NEW.the_geom, 900913));
  point_count integer := greatest(1, floor(total_meters / meters_delta));
  percentage_delta float := 1.0 / point_count;  -- percentage of line between points
BEGIN
  -- RAISE NOTICE 'knots is %', knots;
  -- RAISE NOTICE 'hours_delta is %', hours_delta;
  -- RAISE NOTICE 'start_time is %', start_time;
  -- RAISE NOTICE 'meters_delta is %', meters_delta;
  -- RAISE NOTICE 'total_meters is %', total_meters;
  -- RAISE NOTICE 'point_count is %', point_count;
  -- RAISE NOTICE 'percentage_delta is %', percentage_delta;
  --
  -- delete existing points associated with this line
  delete from ship_position where line_id = NEW.fid;
  --
  FOR i IN 0..point_count LOOP
    insert into ship_position (line_id, the_geom, time, time_end) values (
      NEW.fid,
      ST_Line_Interpolate_Point(NEW.the_geom, i * percentage_delta),
      NEW.start_time + CAST(i * NEW.hours_delta || ' hours' as interval),
      NEW.start_time + CAST((i + 1) * NEW.hours_delta || ' hours' as interval));
  END LOOP;
  --
  return NULL;
END;
$$ LANGUAGE plpgsql;

drop trigger recalc_path_points_trigger on ship_route;
CREATE TRIGGER recalc_path_points_trigger
  AFTER INSERT OR UPDATE OR DELETE ON ship_route
  FOR EACH ROW EXECUTE PROCEDURE recalc_path_points();

-- update ship_route set hours_delta = 4;
-- select time from ship_position;
