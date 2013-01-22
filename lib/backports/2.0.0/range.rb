class Range
  def bsearch
    return to_enum __method__ unless block_given?
    from = self.begin
    to   = self.end
    unless from.is_a?(Numeric) && to.is_a?(Numeric)
      raise TypeError, "can't do binary search for #{from.class}"
    end

    midpoint = nil
    if from.is_a?(Integer) && to.is_a?(Integer)
      convert = ->{ midpoint }
    else
      map = ->(pk, unpk, nb) do
        result, = [nb.abs].pack(pk).unpack(unpk)
        nb < 0 ? -result : result
      end.curry
      i2f = map['q', 'D']
      f2i = map['D', 'q']
      from = f2i[from.to_f]
      to = f2i[to.to_f]
      convert = -> { i2f[midpoint] }
    end
    to -= 1 if exclude_end?
    satisfied = nil
    while from <= to do
      midpoint = (from + to).div(2)
      result = yield(cur = convert.call)
      if result.is_a? Numeric
        return cur if result == 0
        result = result < 0
      else
        satisfied = cur if result
      end

      if result
        to = midpoint - 1
      else
        from = midpoint + 1
      end
    end
    satisfied
  end unless method_defined? :bsearch
end
