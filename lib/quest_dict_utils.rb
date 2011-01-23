module QuestDictUtils
  
  def self.levenshtein_distance(string1, string2)
    
    m = string1.length
    n = string2.length
    
    return m if 0 == n
    return n if 0 ==m
    
    d = (0..m).to_a

    (1..n).each do |j|
      current = []
      current[0] = j
      
      (1..m).each do|i|  

        if string1[i-1] == string2[j-1]
          current[i] = d[i-1]
        else
          current[i] =[current[i-1]+1, d[i]+1,d[i-1]+1].min
        end    
        # puts " #{i},#{j} Comparing #{string1[i-1]} #{string2[j-1]} (prev: #{d[i-1]}, #{current[i-1]}, #{d[i]}) = #{current[i]}"
      end
      d = current 
    end
    return d[m]
  end
  
end

