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
  
  class CollectionTwiddler < Twiddler
    def initialize selected, pool, numToSelect
      super numToSelect, pool.size
      @selected = selected
      @pool = pool
      @numToSelect = numToSelect
    end
    
    def next
      x, q, z, hadNext = twiddle
      
      # Apply the next swap -- Note that when the return value is false, z and x are set such that 
      # they put an item in from the pool that is already in selected at the given position--in other
      # words, its a no-op swap.  The judgment call is to perform one pointless assignment at loop
      # end rather than test hadNext on every iteration.
      if hadNext
        @selected[z] = @pool[x]
      end
        
      return hadNext
    end
  end

  class BitsetTwiddler < Twiddler
    def initialize bitSet, numBitsOn, numBitsTotal
      super(numBitsOn, numBitsTotal)
      @bitSet = bitSet
      @numBitsOn = numBitsOn
      @numBitsTotal = numBitsTotal
    end
    
    def next
      x, y, q, hadNext = twiddle

      # Apply the next swap -- Note that when the return value is false, z and x are set such that 
      # they put an item in from the pool that is already in selected at the given position--in other
      # words, its a no-op swap.  The judgment call is to perform one pointless assignment at loop
      # end rather than test hadNext on every iteration.
      if hadNext
        @bitSet[x] = 1
        @bitSet[y] = 0
      end
      
      return hadNext
    end
  end
  
  # A bit of debugging leftover.  Harmless.
  def runBitTest numOn, numTotal
    bitSet = Array.new(numTotal, 0)
    for i in (numTotal-numOn)..(numTotal-1) do bitSet[i] = 1; end
    bt = BitsetTwiddler.new(bitSet, numOn, numTotal)
    while bt.next do puts bt.inspect; end
  end
end
