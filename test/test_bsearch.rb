require_relative 'test_helper'
require_relative '../lib/backports/2.0'

class TestBsearch < Test::Unit::TestCase
  def check_bsearch_values(range, search)
    from, to = range.begin, range.end
    cmp = range.exclude_end? ? :< : :<=

    # (0) trivial test
    r = Range.new(to, from, range.exclude_end?).bsearch do
      fail
    end
    assert_equal nil, r

    r = (to...to).bsearch do
      fail
    end
    assert_equal nil, r

    # prepare for others
    yielded = []
    r = range.bsearch do |val|
      yielded << val
      val >= search
    end

    # (1) log test
    max = case from
          when Float then 65
          when Integer then Math.log(to-from+(range.exclude_end? ? 0 : 1), 2).to_i + 1
          end
    assert yielded.size <= max

    # (2) coverage test
    expect =  if search < from
                from
              elsif search.send(cmp, to)
                search
              else
                nil
              end
    assert_equal expect, r

    # (3) uniqueness test
    assert_equal nil, yielded.uniq!

    # (4) end of range test
    case
    when range.exclude_end?
      assert !yielded.include?(to)
      assert r != to
    when search >= to
      assert yielded.include?(to)
      assert_equal search == to ? to : nil, r
    end

    # start of range test
    if search <= from
      assert yielded.include?(from)
      assert_equal from, r
    end

    # (5) out of range test
    yielded.each do |val|
      assert from <= val && val.send(cmp, to)
    end
  end

  def test_range_bsearch
    ints   = [-1 << 100, -123456789, -42, -1, 0, 1, 42, 123456789, 1 << 100]
    floats = [-Float::INFINITY, -Float::MAX, -42.0, -4.2, -Float::EPSILON, -Float::MIN, 0.0, Float::MIN, Float::EPSILON, Math::PI, 4.2, 42.0, Float::MAX, Float::INFINITY]

    [ints, floats].each do |values|
      values.combination(2).to_a.product(values).each do |(from, to), search|
        check_bsearch_values(from..to, search)
        check_bsearch_values(from...to, search)
      end
    end
  end
end
