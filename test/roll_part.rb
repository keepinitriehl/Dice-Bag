# Encoding: UTF-8

describe DiceBag::RollPart do
  describe 'for a non-target roll' do
    describe 'with no options' do
      before do
        @part = xdx('3d6').first.last
      end

      describe 'before it rolls' do
        it 'must not have rolled' do
          _(@part.rolled?).must_equal false
        end

        it 'has an empty tally' do
          _(@part.tally).must_be_empty
        end

        it 'must have count of 3' do
          _(@part.count).must_equal 3
        end

        it 'must have 6 sides' do
          _(@part.sides).must_equal 6
        end
      end

      describe 'after it rolls' do
        before do
          make_not_so_random!

          @part.roll
        end

        it 'should have rolled' do
          _(@part.rolled?).must_equal true
        end

        it 'must have a total of 11' do
          _(@part.total).must_equal 11
        end

        it 'must have a tally' do
          _(@part.tally).wont_be_empty
        end

        it 'must have a tally with 3 items' do
          _(@part.tally.size).must_equal 3
        end
      end
    end

    describe 'with an exploding option' do
      before do
        @part = xdx('3d6 e6').first.last

        make_not_so_random!

        @part.roll
      end

      it 'should have a total of 14' do
        _(@part.total).must_equal 14
      end

      it 'should have a tally of 4 items' do
        _(@part.tally[0].size).must_equal 3
        _(@part.tally[1].size).must_equal 1
      end
    end

    describe 'with an exploding indefinitely option' do
      before do
        @part = xdx('3d6 ie3').first.last

        make_not_so_random!

        @part.roll
      end

      it 'should have a total of 21' do
        _(@part.total).must_equal 21
      end

      it 'should explode 5 times' do
        _(@part.tally.size).must_equal 5
      end
    end

    describe 'with a drop option' do
      before do
        @part = xdx('3d6 d1').first.last

        make_not_so_random!

        @part.roll
      end

      it 'should have a total of 10' do
        _(@part.total).must_equal 10
      end

      it 'should have a tally of 3 items' do
        _(@part.tally.size).must_equal 3
      end
    end

    describe 'with a keep option' do
      before do
        @part = xdx('3d6 k1').first.last

        make_not_so_random!

        @part.roll
      end

      it 'should have a total of 6' do
        _(@part.total).must_equal 6
      end

      it 'should have a tally of 3 items' do
        _(@part.tally.size).must_equal 3
      end
    end
  end

  describe 'for a target roll' do
    describe 'with no options' do
      before do
        @part = xdx('3d6 t4').first.last

        make_not_so_random!

        @part.roll
      end

      it 'should have a total of 2' do
        _(@part.total).must_equal 2
      end
    end

    describe 'with an exploding option' do
      before do
        @part = xdx('3d6 e1 t4').first.last

        make_not_so_random!

        @part.roll
      end

      it 'should have a total of 2' do
        _(@part.total).must_equal 3
      end

      it 'should have a tally of 3 items and 3 rerolls' do
        _(@part.tally[0].size).must_equal 3
        _(@part.tally[1].size).must_equal 3
      end
    end

    describe 'with a drop option' do
      before do
        @part = xdx('3d6 d1 t4').first.last

        make_not_so_random!

        @part.roll
      end

      it 'should have a total of 2' do
        _(@part.total).must_equal 2
      end

      it 'should have a tally of 3 items' do
        _(@part.tally.size).must_equal 3
      end
    end

    describe 'with a keep option' do
      before do
        @part = xdx('3d6 k1 t4').first.last

        make_not_so_random!

        @part.roll
      end

      it 'should have a total of 1' do
        _(@part.total).must_equal 1
      end

      it 'should have a tally of 3 items' do
        _(@part.tally.size).must_equal 3
      end
    end
  end
end
