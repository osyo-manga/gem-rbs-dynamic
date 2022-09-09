def func1(*)
  "func1"
end

def func2(*)
  func1
  "func2"
  func1 func1
  "func2"
end

def func3(*)
  func1
  "func3"
  func2 func1
  "func3"
  "func3"
end

def func4(*)
  func3
  func1
  func2 func3
end

func4
func4 func2
