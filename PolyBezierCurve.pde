/***************************************************
 *                                                 *
 *    A generic Poly-Bezier curve implementation   *
 *                                                 *
 ***************************************************/

/**
 * A Poly-Bezier curve class
 */
class PolyBezierCurve {
  int pointCount = -1;
  ArrayList<BezierCurve> segments;

  /**
   * Form a new poly-bezier
   */
  PolyBezierCurve() {
    segments = new ArrayList<BezierCurve>();
  }

  /**
   * Add a segment to this poly-bezier
   */
  void addCurve(BezierCurve curve) {
    int len = segments.size();
    segments.add(curve);
    if(len==0) { return; }
    // make the segments share endpoints.
    BezierCurve pc = segments.get(len-1);
    Point[] points = pc.points;
    int plen = points.length;
    Point last = points[plen-1];
    curve.points[0] = last;
    curve.points[1] = last.reflect(points[plen-2]);
    curve.update();
    // get order
    if(pointCount==-1) {
      pointCount = plen;
    }
  }

  /**
   * return the approximate 't' that the mouse
   * is near. If no approximate value can be found,
   * return -1, which is an impossible value.
   *
   * Note that for poly-beziers, t can range from 0
   * to n, where n is the number of segments.
   */
  float over(float mx, float my) {
    float t;
    int n = -1;
    for(BezierCurve c: segments) {
      n++;
      t = c.over(mx,my);
      if(t!=-1) { return t+n; }
    }
    return -1;
  }

  /**
   * return the point we are over, if we're over a point
   */
  int overPoint(float mx, float my) {
    Point p;
    int n = 0;
    for(BezierCurve c: segments) {
      for(int i=0; i<pointCount; i++) {
        p = c.points[i];
        if(abs(p.x-mx) < 5 && abs(p.y-my) < 5) {
          return n+i;
        }
      }
      n += pointCount;
    }
    return -1;
  }

  /**
   * get a point [point] form a segment [segment]
   */
  Point getPoint(int segment, int point) {
    return segments.get(segment).points[point];
  }

  /**
   * Move a curve point without any constraints
   */
  // FIXME: compact with the other two functions
  void movePoint(int idx, float nx, float ny) {
    int n = floor((float)idx/pointCount),
        i = idx%pointCount;
    Point p = getPoint(n,i);
    // get delta
    float dx = nx - p.x,
          dy = ny - p.y;
    p.x = nx;
    p.y = ny;
    segments.get(n).update();
    // update the adjacent section, if we moved an endpoint.
    if(i==0 && n>0) { segments.get(n-1).update(); }
    if(i==pointCount-1 && n<segments.size()-1) { segments.get(n+1).update(); }
  }

  /**
   * Move a curve point; this only preserves the poly-Bezier
   * angular relation, but allows alternative tangental
   * strength. To constrain on derivative value, use the
   * movePointConstrained function, instead.
   */
  // FIXME: compact with the other two functions
  void movePointHalfConstrained(int idx, float nx, float ny) {
    int n = floor((float)idx/pointCount),
        i = idx%pointCount;
    Point p = getPoint(n,i);
    // get delta
    float dx = nx - p.x,
          dy = ny - p.y;
    p.x = nx;
    p.y = ny;
    // update local control point
    Point m;
    if(i==0 && n > 0) {
      m = getPoint(n,1);
      m.moveBy(dx,dy);
      // also move related control in prev
      m = getPoint(n-1,pointCount-2);
      m.moveBy(dx,dy);
    }
    else if(i==pointCount-1 && n < segments.size()-1) {
      m = getPoint(n,i-1);
      m.moveBy(dx,dy);
      // also move related control in next
      m = getPoint(n+1,1);
      m.moveBy(dx,dy);
    }
    segments.get(n).update();
    // cascade changes
    if(n>0) { updateDown(n-1, false); }
    if(n<segments.size()-1) { updateUp(n+1, false); }
  }

  /**
   * Move a curve point; this preserves the poly-Bezier
   * derivative. To preserve angular relation, but allow
   * alternative tangental strength, use the
   * movePointHalfConstrained function, instead.
   */
  // FIXME: compact with the other two functions
  void movePointConstrained(int idx, float nx, float ny) {
    int n = floor((float)idx/pointCount),
        i = idx%pointCount;
    Point p = getPoint(n,i);
    // get delta
    float dx = nx - p.x,
          dy = ny - p.y;
    p.x = nx;
    p.y = ny;
    // update local control point
    Point m;
    if(i==0 && n > 0) {
      m = getPoint(n,1);
      m.moveBy(dx,dy); }
    else if(i==pointCount-1 && n < segments.size()-1) {
      m = getPoint(n,i-1);
      m.moveBy(dx,dy); }
    segments.get(n).update();
    // cascade changes
    if(n>0) { updateDown(n-1, true); }
    if(n<segments.size()-1) { updateUp(n+1, true); }
  }

  /**
   * Update all downstream segments. If "full" is
   * true the derivative at the join is maintained.
   * Otherwise the angle is maintained, but the
   * downstream strength is preserved.
   */
  void updateDown(int segment, boolean full) {
    BezierCurve master = segments.get(segment+1),
                current = segments.get(segment);
    Point c = current.points[pointCount-2],
          m = master.points[0],
          reflected = m.reflect(master.points[1]);
    if(full) { current.points[pointCount-2] = reflected; }
    else {
      float dx,dy,phi1,phi2;
      dx = reflected.x - m.x;
      dy = reflected.y - m.y;
      phi1 = atan2(dy,dx);
      dx = c.x - m.x;
      dy = c.y - m.y;
      phi2 = atan2(dy,dx);
      current.points[pointCount-2].rotateOver(m, phi1-phi2);
    }
    current.update();
    if(segment>0) { updateDown(segment-1, full); }
  }

  /**
   * Update all upstream segments. If "full" is
   * true the derivative at the join is maintained.
   * Otherwise the angle is maintained, but the
   * upstream strength is preserved.
   */
  void updateUp(int segment, boolean full) {
    BezierCurve master = segments.get(segment-1),
                current = segments.get(segment);
    Point c = current.points[1],
          m = master.points[pointCount-2],
          reflected = current.points[0].reflect(m);
    if(full) { current.points[1] = reflected; }
    else {
      float dx,dy,phi1,phi2;
      dx = reflected.x - m.x;
      dy = reflected.y - m.y;
      phi1 = atan2(dy,dx);
      dx = c.x - m.x;
      dy = c.y - m.y;
      phi2 = atan2(dy,dx);
      c.rotateOver(m, phi1-phi2);
    }
    current.update();
    if(segment<segments.size()-1) { updateUp(segment+1, full); }
  }

  /**
   *
   */
  ArrayList<CurvePair> getIntersections(PolyBezierCurve other) {
    ArrayList<CurvePair> intersections = new ArrayList<CurvePair>();
    BezierCurve segment;
    for(int i=0; i<segments.size(); i++) {
      segment = segments.get(i);
      // get all curvepairs in which this segment intersects
      // with the other PolyBezierCurve
      ArrayList<CurvePair> cps = other.intersects(segment, i);
      for(CurvePair cp: cps) {
        println(cp.t1 + "--" + cp.t1);
        cp.c1 = segment;
        cp.t1 += i;
        cp.s1 = i; 
        intersections.add(cp);
      }
    }
    return intersections;
  }
  
  /**
   *
   */
  ArrayList<CurvePair> intersects(BezierCurve c, int ci) {
    ArrayList<CurvePair> intersections = new ArrayList<CurvePair>(),
                         currentIntersections;
    BezierCurve segment;
    for(int i=0; i<segments.size(); i++) {
      segment = segments.get(i);
      // get all curvepairs in which these two segments intersect
      currentIntersections = comp.findIntersections(c, segment);
      for(CurvePair cp: currentIntersections) {
        println("  -> "+ci+"/"+i);
        cp.setTValues();
        cp.c2 = segment;
        cp.t2 += i;
        cp.s2 = i; 
        intersections.add(cp); 
      }
    }
    return intersections;
  }
  
  /**
   * Split this poly curve between c1's t=t1 and c2's t=t2.
   */
  PolyBezierCurve split(float t1, float t2) {
    int pos1 = (int) t1, pos2 = (int) t2;
    BezierCurve c1 = segments.get(pos1),
                c2 = segments.get(pos2);
    t1 = t1 % 1;
    t2 = t2 % 1;
    PolyBezierCurve newPoly = new PolyBezierCurve();
    // subcurve on a single section?
    if(pos1==pos2) { newPoly.addCurve(c1.split(t1,t2)); }
    else {
      // not on a single section... more work =)
      newPoly.addCurve(c1.split(t1)[1]);
      while(++pos1 < pos2) { newPoly.addCurve(segments.get(pos1)); }
      newPoly.addCurve(c2.split(t2)[0]);
    }
    return newPoly;
  }
  
  PolyBezierCurve[] split(float t) {
    int pos = (int) t;
    BezierCurve c = segments.get(pos);
    t = t % 1;
    PolyBezierCurve[] newPolies = {new PolyBezierCurve(), new PolyBezierCurve()};
    int i=0;
    while(i++<pos) { newPolies[0].addCurve(segments.get(i)); }
    BezierCurve[] bcs = segments.get(pos).split(t);
    newPolies[0].addCurve(bcs[0]);
    newPolies[1].addCurve(bcs[1]);
    while(++pos<segments.size()) { newPolies[1].addCurve(segments.get(pos)); }
    return newPolies;
  }

  /**
   * draw this poly-Bezier
   */
  void draw() { for(BezierCurve c: segments) { c.draw(); }}
  void draw(color col) { for(BezierCurve c: segments) { c.draw(col); }}  
}

