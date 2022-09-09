def func1(*)
  yield
  yield
end

def func2(*)
  yield func1 { |a| }
end

func2 { |a| }
