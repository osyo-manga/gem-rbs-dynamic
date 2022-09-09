def func1(*)
  yield
end

def func2(*)
  yield
end

def func3
  func2 { |a|
    func1 { |a| }
  }
end

func3
