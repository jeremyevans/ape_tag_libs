import ApeTag
import newApeTag
from cStringIO import StringIO

def tagsequal(a, b):
    return test('getrawtags', a, b) and test('gettagfields', a, b)
    
def hastags(a,b):
    return newApeTag.hastags(a) == newApeTag.hastags(b)
           
def filesize(x):
    x.seek(0,2)
    return x.tell()
    
def test(func, a, b, *args):
    return getattr(ApeTag, func)(a, *args) == getattr(newApeTag, func)(b, *args)

old, new = StringIO(), StringIO()

print 'hastags equal:', hastags(old,new)

assert test('createtags', old, new, {'Title':'Black Pepper'})
print 'createtags equal:', tagsequal(old, new)

assert test('updatetags', old, new, {'Album':'White Salt'})
print 'updatetags equal:', tagsequal(old, new)
print ApeTag.gettagfields(old)
print newApeTag.gettagfields(new)

print 'hastags equal:', hastags(old,new)

assert test('replacetags', old, new, {'Comment':'Yellow Snow', 'Genre':'BLah'})
print 'replacetags equal:', tagsequal(old, new)
print ApeTag.gettagfields(old)
print newApeTag.gettagfields(new)

assert test('updatetags', old, new, {'Year':'1999'}, ['Genre'])
print 'updatetags equal:', tagsequal(old, new)
print ApeTag.gettagfields(old)
print newApeTag.gettagfields(new)

assert test('deletetags', old, new)
print 'hastags equal:', hastags(old,new)
