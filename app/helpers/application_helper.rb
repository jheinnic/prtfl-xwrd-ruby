module ApplicationHelper
  class Twiddler
    def initialize m, n
      @n = n
      # @m = m

      @p = Array.new(n+2, n+1)
      # @p[0] = @n+1;

      for i in 1..n-m do @p[i] = 0; end
      for i in n-m+1..n do @p[i] = i+m-n; end
      @p[n+1] = -2;
      
      if m == 0 then @p[1] = 1; end
    end
    
    MESSAGE = "Abstract Method Call"
    def next
      raise MESSAGE
    end

    def twiddle # : (Int, Int, Int, Boolean) = {
      j = 1;
      while @p[j] <= 0 do j += 1; end
        
      if @p[j-1] == 0
        for i in 2..j-1 do @p[i] = -1; end
    
        @p[j] = 0;
        @p[1] = 1;
        # *x = *z = 0
        # *y = j-1
        return 0, j-1, 0, true
      else
        if j > 1 then @p[j-1] = 0; end
        
        j = j+1
        while @p[j] > 0 do j = j+1; end
        
        k = j-1
        i = j
        while @p[i] == 0 do @p[i] = -1; i = i+1; end;
    
        if @p[i] == -1 then
          @p[i] = @p[k];
          # *z = @p[k]-1;
          zVal = @p[k]-1;
          @p[k] = -1;
    
          # *x = i-1
          # *y = k-1
          return  i-1, k-1, zVal, true
        elsif i == @p[0]
          return  0, j-1, 0, false
        else
          @p[j] = @p[i]
          # *z = @p[i]-1
          zVal = @p[i]-1
          @p[i] = 0
    
          # *x = j-1
          # *y = i-1
          return j-1, i-1, zVal, true
        end
      end
    end
  end
  
  # TODO: Can we use @n instead of a copy of it?
  class CollectionTwiddler < Twiddler
    include Enumerable

    def initialize numToSelect, pool
      super numToSelect, pool.size 

      @numToSelect = numToSelect
      @pool = pool
    end
    
    # Be aware that the value of selected is reused with altered contents!
    # Copy it before leaving a call to the enumerator's block if access to
    # pervious permutations is needed!
    def each 
      hadNext = @n > @numToSelect
      selected = @pool.slice(0, @numToSelect)

      while (hadNext)
        x, q, z, hadNext = twiddle
        yield selected
        selected[z] = @pool[x]
      end
    end
  end

  # TODO: Can we use @n instead of a copy of it?
  class BitsetTwiddler < Twiddler
    include Enumerable

    def initialize numBitsOn, numBitsTotal
      super numBitsOn, numBitsTotal

      @numBitsTotal = numBitsTotal
      @numBitsOn = numBitsOn
      
      @allBitsOn  = (1 << numBitsTotal) - 1
      @oneBitOn   = (0...numBitsTotal).map { |x| 1 << x }
      @oneBitOff  = @oneBitOn.map { |x| @allBitsOn & ~x }
      @initialBitSet = (1 << numBitsTotal) - (1 << (numBitsTotal-numBitsOn))
    end
    
    def each 
      hadNext = @numBitsTotal > @numBitsOn
      currentBitSet = @initialBitSet

      while(hadNext)
        x, y, q, hadNext = twiddle
        yield currentBitSet
        currentBitSet = currentBitSet & @oneBitOff[y] | @oneBitOn[x]
      end
    end
  end

  class SwapTwiddler < Twiddler
    include Enumerable

    def initialize numBitsOn, numBitsTotal
      super numBitsOn, numBitsTotal
    end
    
    def each 
      x, y, q, hadNext = twiddle
      yieldVal = [y, x]

      while(hadNext)
	yield yieldVal   # Yield a pair, [ElementOut, ElementIn].

        x, y, q, hadNext = twiddle
        yieldVal[0] = y
        yieldVal[1] = x
      end
    end
  end
end
