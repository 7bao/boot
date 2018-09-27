
void show(void)
{
	int i;
	int j = 15;
	char *p;
	for (i = 0xa0000; i<=0xaffff;i++)
	{	p = i;
		*p = j;
	}
}
